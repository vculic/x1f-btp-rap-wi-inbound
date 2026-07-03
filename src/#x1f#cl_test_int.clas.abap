CLASS /x1f/cl_test_int DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES /x1f/if_test_int.
    INTERFACES if_http_service_extension.

ENDCLASS.



CLASS /x1f/cl_test_int IMPLEMENTATION.

  METHOD /x1f/if_test_int~list.
    IF iv_id IS INITIAL.
      SELECT * FROM /x1f/test_int
        INTO CORRESPONDING FIELDS OF TABLE @rt_data
        ORDER BY created_on DESCENDING, created_time DESCENDING.
    ELSE.
      SELECT * FROM /x1f/test_int
        INTO CORRESPONDING FIELDS OF TABLE @rt_data
        WHERE id = @iv_id.
    ENDIF.
  ENDMETHOD.

  METHOD /x1f/if_test_int~create.
    rs_data-id           = cl_system_uuid=>create_uuid_x16_static( ).
    rs_data-description  = iv_description.
    rs_data-created_on   = sy-datum.
    rs_data-created_time = sy-uzeit.
    rs_data-created_by   = sy-uname.
    rs_data-changed_on   = sy-datum.
    rs_data-changed_time = sy-uzeit.
    rs_data-changed_by   = sy-uname.

    INSERT /x1f/test_int FROM @rs_data.
  ENDMETHOD.

  METHOD /x1f/if_test_int~update.
    SELECT SINGLE @abap_true
      FROM /x1f/test_int
      WHERE id = @iv_id
      INTO @rv_found.

    IF rv_found = abap_true.
      DATA(lv_now_date) = sy-datum.
      DATA(lv_now_time) = sy-uzeit.
      DATA(lv_user)     = sy-uname.

      UPDATE /x1f/test_int
        SET description  = @iv_description,
            changed_on   = @lv_now_date,
            changed_time = @lv_now_time,
            changed_by   = @lv_user
        WHERE id = @iv_id.
    ENDIF.
  ENDMETHOD.

  METHOD if_http_service_extension~handle_request.

    DATA lv_json TYPE string.

    TRY.
        CASE request->get_method( ).

          WHEN 'GET'.
            DATA lv_id_x16 TYPE sysuuid_x16.
            DATA(lv_id_str) = request->get_uri_query_parameter( 'id' ).
            IF lv_id_str IS NOT INITIAL.
              lv_id_x16 = cl_system_uuid=>convert_uuid_c36_to_x16( CONV #( lv_id_str ) ).
            ENDIF.

            DATA(lt_result) = /x1f/if_test_int~list( lv_id_x16 ).
            lv_json = xco_cp_json=>data->from_abap( lt_result )->to_string( ).
            response->set_status( 200 ).

          WHEN 'POST'.
            DATA: BEGIN OF ls_create_input,
                    description TYPE char100,
                  END OF ls_create_input.
            xco_cp_json=>data->from_string( request->get_text( ) )->write_to( REF #( ls_create_input ) ).

            DATA(ls_created) = /x1f/if_test_int~create( ls_create_input-description ).
            lv_json = xco_cp_json=>data->from_abap( ls_created )->to_string( ).
            response->set_status( 201 ).

          WHEN 'PUT'.
            DATA(lv_put_id_str) = request->get_uri_query_parameter( 'id' ).

            DATA: BEGIN OF ls_update_input,
                    description TYPE char100,
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
