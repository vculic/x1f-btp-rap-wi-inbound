class /X1F/CL_TEST_INT definition
  public
  final
  create public .

  public section.
    interfaces /x1f/if_test_int.
    interfaces if_http_service_extension.

  protected section.
  private section.
ENDCLASS.



CLASS /X1F/CL_TEST_INT IMPLEMENTATION.

  METHOD /x1f/if_test_int~list.
    " cloud adaptation: explicit column list instead of SELECT * / INTO CORRESPONDING FIELDS OF
    " (obsolete addition, and the DB row includes MANDT which ty_test_int does not - caused
    " a "not unicode convertible" mismatch between rt_data and the table's flat layout)
    IF iv_id IS INITIAL.
      SELECT id, description, created_by, created_at, changed_by, changed_at
        FROM /x1f/test_int
        ORDER BY created_at DESCENDING
        INTO TABLE @rt_data.
    ELSE.
      SELECT id, description, created_by, created_at, changed_by, changed_at
        FROM /x1f/test_int
        WHERE id = @iv_id
        INTO TABLE @rt_data.
    ENDIF.
  ENDMETHOD.

  METHOD /x1f/if_test_int~create.
    " cloud adaptation: cl_system_uuid=>create_uuid_x16_static( ) raises cx_uuid_error,
    " declared in the RAISING clause of /x1f/if_test_int~create and propagated to the
    " caller (handle_request catches it via the generic CATCH cx_root below)
    rs_data-id          = cl_system_uuid=>create_uuid_x16_static( ).
    rs_data-description = iv_description.

    " cloud adaptation: sy-uname / sy-datum / sy-uzeit replaced with released cloud APIs
    rs_data-created_by  = cl_abap_context_info=>get_user_technical_name( ).
    rs_data-created_at  = utclong_current( ).
    rs_data-changed_by  = rs_data-created_by.
    rs_data-changed_at  = rs_data-created_at.

    INSERT /x1f/test_int FROM @rs_data.
  ENDMETHOD.

  METHOD /x1f/if_test_int~update.
    SELECT SINGLE @abap_true
      FROM /x1f/test_int
      WHERE id = @iv_id
      INTO @rv_found.

    IF rv_found = abap_true.
      DATA(lv_now)  = utclong_current( ).
      DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

      UPDATE /x1f/test_int
        SET description = @iv_description,
            changed_by   = @lv_user,
            changed_at   = @lv_now
        WHERE id = @iv_id.
    ENDIF.
  ENDMETHOD.

  METHOD if_http_service_extension~handle_request.

    DATA lv_json TYPE string.

    TRY.
        CASE request->get_method( ).

          WHEN 'GET'.
            " cloud adaptation: get_uri_query_parameter( ) belongs to the old IF_REST_REQUEST
            " API and does not exist on IF_WEB_HTTP_REQUEST - get_form_field( ) reads both
            " URL query-string parameters (?id=...) and form-encoded body fields
            DATA lv_id_x16 TYPE sysuuid_x16.
            DATA(lv_id_str) = request->get_form_field( 'id' ).
            IF lv_id_str IS NOT INITIAL.
              lv_id_x16 = cl_system_uuid=>convert_uuid_c36_to_x16( CONV #( lv_id_str ) ).
            ENDIF.

            DATA(lt_result) = /x1f/if_test_int~list( lv_id_x16 ).
            lv_json = xco_cp_json=>data->from_abap( lt_result )->to_string( ).
            response->set_status( 200 ).

          WHEN 'POST'.
            DATA: BEGIN OF ls_create_input,
                    description TYPE /x1f/test_desc,
                  END OF ls_create_input.
            xco_cp_json=>data->from_string( request->get_text( ) )->write_to( REF #( ls_create_input ) ).

            DATA(ls_created) = /x1f/if_test_int~create( ls_create_input-description ).
            lv_json = xco_cp_json=>data->from_abap( ls_created )->to_string( ).
            response->set_status( 201 ).

          WHEN 'PUT'.
            DATA(lv_put_id_str) = request->get_form_field( 'id' ).

            DATA: BEGIN OF ls_update_input,
                    description TYPE /x1f/test_desc,
                  END OF ls_update_input.
            xco_cp_json=>data->from_string( request->get_text( ) )->write_to( REF #( ls_update_input ) ).

            DATA(lv_found) = /x1f/if_test_int~update(
                                iv_id          = cl_system_uuid=>convert_uuid_c36_to_x16( CONV #( lv_put_id_str ) )
                                iv_description = ls_update_input-description ).

            IF lv_found = abap_true.
              response->set_status( 200 ).
              lv_json = `{}`.
            ELSE.
              response->set_status( 404 ).
              lv_json = `{ "error" : "not found" }`.
            ENDIF.

          WHEN OTHERS.
            response->set_status( 405 ).
            lv_json = `{ "error" : "method not allowed" }`.
        ENDCASE.

      CATCH cx_root INTO DATA(lx_error).
        response->set_status( 500 ).
        lv_json = |\{ "error" : "{ lx_error->get_text( ) }" \}|.
    ENDTRY.

    response->set_header_field( i_name = 'Content-Type' i_value = 'application/json' ).
    response->set_text( lv_json ).

  ENDMETHOD.

ENDCLASS.
