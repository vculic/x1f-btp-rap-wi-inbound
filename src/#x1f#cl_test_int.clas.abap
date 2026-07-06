class /X1F/CL_TEST_INT definition
  public
  final
  create public .

  public section.
    interfaces /x1f/if_test_int.
    interfaces if_http_service_extension.

  protected section.
  private section.
    " accepts both UUID formats a client may send: 36 chars with hyphens (C36)
    " and 32-char hex (C32, the format XCO JSON produces for RAW16 fields)
    methods to_uuid_x16
      importing
        iv_value       type string
      returning
        value(rv_uuid) type sysuuid_x16
      raising
        cx_uuid_error.
ENDCLASS.



CLASS /X1F/CL_TEST_INT IMPLEMENTATION.

  METHOD to_uuid_x16.
    DATA(lv_value) = condense( iv_value ).

    CASE strlen( lv_value ).
      WHEN 36.
        " SYSUUID_C36 is lowercase hex with hyphens
        cl_system_uuid=>convert_uuid_c36_static(
          EXPORTING uuid     = CONV sysuuid_c36( to_lower( lv_value ) )
          IMPORTING uuid_x16 = rv_uuid ).
      WHEN 32.
        " SYSUUID_C32 is uppercase hex without hyphens
        cl_system_uuid=>convert_uuid_c32_static(
          EXPORTING uuid     = CONV sysuuid_c32( to_upper( lv_value ) )
          IMPORTING uuid_x16 = rv_uuid ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE cx_uuid_error.
    ENDCASE.
  ENDMETHOD.

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

    " cloud adaptation: sy-uname / sy-datum / sy-uzeit replaced with released cloud APIs.
    " created_at/changed_at are TIMESTAMPL (ABP_CREATION_TSTMPL / ABP_LASTCHANGE_TSTMPL),
    " not UTCLONG - GET TIME STAMP FIELD stays allowed in ABAP Cloud for this type.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.

    rs_data-created_by  = cl_abap_context_info=>get_user_technical_name( ).
    rs_data-created_at  = lv_now.
    rs_data-changed_by  = rs_data-created_by.
    rs_data-changed_at  = lv_now.

    " rs_data (ty_test_int) has no MANDT field, so it is not unicode convertible to the
    " DB row - CORRESPONDING builds a proper /x1f/test_int row (client is filled implicitly)
    INSERT /x1f/test_int FROM @( CORRESPONDING /x1f/test_int( rs_data ) ).
  ENDMETHOD.

  METHOD /x1f/if_test_int~update.
    SELECT SINGLE @abap_true
      FROM /x1f/test_int
      WHERE id = @iv_id
      INTO @rv_found.

    IF rv_found = abap_true.
      DATA lv_now TYPE timestampl.
      GET TIME STAMP FIELD lv_now.
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
            DATA(lv_id_str) = request->get_form_field( i_name = 'id' ).
            IF lv_id_str IS NOT INITIAL.
              lv_id_x16 = to_uuid_x16( lv_id_str ).
            ENDIF.

            DATA(lt_result) = /x1f/if_test_int~list( lv_id_x16 ).
            lv_json = xco_cp_json=>data->from_abap( lt_result )->to_string( ).
            response->set_status( i_code = 200 i_reason = 'OK' ).

          WHEN 'POST'.
            DATA: BEGIN OF ls_create_input,
                    description TYPE /x1f/test_desc,
                  END OF ls_create_input.
            xco_cp_json=>data->from_string( request->get_text( ) )->write_to( REF #( ls_create_input ) ).

            DATA(ls_created) = /x1f/if_test_int~create( ls_create_input-description ).
            lv_json = xco_cp_json=>data->from_abap( ls_created )->to_string( ).
            response->set_status( i_code = 201 i_reason = 'Created' ).

          WHEN 'PUT'.
            DATA(lv_put_id_str) = request->get_form_field( i_name = 'id' ).

            DATA: BEGIN OF ls_update_input,
                    description TYPE /x1f/test_desc,
                  END OF ls_update_input.
            xco_cp_json=>data->from_string( request->get_text( ) )->write_to( REF #( ls_update_input ) ).

            DATA(lv_found) = /x1f/if_test_int~update(
                                iv_id          = to_uuid_x16( lv_put_id_str )
                                iv_description = ls_update_input-description ).

            IF lv_found = abap_true.
              response->set_status( i_code = 200 i_reason = 'OK' ).
              lv_json = `{}`.
            ELSE.
              response->set_status( i_code = 404 i_reason = 'Not Found' ).
              lv_json = `{ "error" : "not found" }`.
            ENDIF.

          WHEN OTHERS.
            response->set_status( i_code = 405 i_reason = 'Method Not Allowed' ).
            lv_json = `{ "error" : "method not allowed" }`.
        ENDCASE.

      CATCH cx_root INTO DATA(lx_error).
        response->set_status( i_code = 500 i_reason = 'Internal Server Error' ).
        lv_json = |\{ "error" : "{ lx_error->get_text( ) }" \}|.
    ENDTRY.

    response->set_content_type( 'application/json' ).
    response->set_text( lv_json ).

  ENDMETHOD.

ENDCLASS.
