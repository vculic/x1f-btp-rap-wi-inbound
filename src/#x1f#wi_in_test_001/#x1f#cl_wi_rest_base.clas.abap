class /X1F/CL_WI_REST_BASE definition
  public
  abstract
  create public .

  public section.
    " Generic REST engine. Mirrors the old (abstract) subclass of CL_REST_RESOURCE:
    " all reusable HTTP/JSON plumbing lives here, nothing table-specific.
    " A concrete resource is created by INHERITING FROM this class and redefining
    " the four hooks below - no table name / structure is ever mentioned here.
    interfaces if_http_service_extension.

  protected section.
    " ---- hooks a concrete resource must provide (table-specific lives there) ----

    "! Read all rows. Returns a data reference to an internal table.
    methods read_all abstract
      returning value(rr_data) type ref to data
      raising   cx_static_check.

    "! Read the row(s) matching a (string) id. Returns a data ref to a table.
    methods read_by_id abstract
      importing iv_id          type string
      returning value(rr_data) type ref to data
      raising   cx_static_check.

    "! Create one or many rows from a JSON body. Returns the created rows.
    methods create_from_json abstract
      importing iv_json        type string
      returning value(rr_data) type ref to data
      raising   cx_static_check.

    "! Update the row identified by id from a JSON body. abap_false => 404.
    methods update_from_json abstract
      importing iv_id           type string
                iv_json         type string
      returning value(rv_found) type abap_bool
      raising   cx_static_check.

    " ---- reusable helper offered to every subclass ----

    "! Generic ABAP-to-JSON: dereference any data ref and serialize via XCO.
    methods to_json
      importing ir_data       type ref to data
      returning value(rv_json) type string.

  private section.
    methods send
      importing io_response type ref to if_web_http_response
                iv_code     type i
                iv_reason   type string
                iv_json     type string.
ENDCLASS.



CLASS /X1F/CL_WI_REST_BASE IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.
    " Generic dispatch: GET -> read, POST -> create, PUT -> update.
    " Any error (incl. cx_uuid_error from a subclass) is turned into HTTP 500.
    TRY.
        CASE request->get_method( ).

          WHEN 'GET'.
            DATA(lv_id) = request->get_form_field( i_name = 'id' ).
            DATA lr_out TYPE REF TO data.
            IF lv_id IS INITIAL.
              lr_out = read_all( ).
            ELSE.
              lr_out = read_by_id( lv_id ).
            ENDIF.
            send( io_response = response
                  iv_code     = 200
                  iv_reason   = 'OK'
                  iv_json     = to_json( lr_out ) ).

          WHEN 'POST'.
            DATA(lr_created) = create_from_json( request->get_text( ) ).
            send( io_response = response
                  iv_code     = 201
                  iv_reason   = 'Created'
                  iv_json     = to_json( lr_created ) ).

          WHEN 'PUT'.
            DATA(lv_found) = update_from_json(
                               iv_id   = request->get_form_field( i_name = 'id' )
                               iv_json = request->get_text( ) ).
            IF lv_found = abap_true.
              send( io_response = response iv_code = 200 iv_reason = 'OK' iv_json = `{}` ).
            ELSE.
              send( io_response = response iv_code = 404 iv_reason = 'Not Found'
                    iv_json = `{ "error" : "not found" }` ).
            ENDIF.

          WHEN OTHERS.
            send( io_response = response iv_code = 405 iv_reason = 'Method Not Allowed'
                  iv_json = `{ "error" : "method not allowed" }` ).
        ENDCASE.

      CATCH cx_root INTO DATA(lx_error).
        send( io_response = response
              iv_code     = 500
              iv_reason   = 'Internal Server Error'
              iv_json     = |\{ "error" : "{ lx_error->get_text( ) }" \}| ).
    ENDTRY.
  ENDMETHOD.

  METHOD to_json.
    " field symbol: dereference the generic data ref, then let XCO serialize it.
    FIELD-SYMBOLS <data> TYPE any.
    ASSIGN ir_data->* TO <data>.
    IF <data> IS ASSIGNED.
      rv_json = xco_cp_json=>data->from_abap( <data> )->to_string( ).
    ENDIF.
  ENDMETHOD.

  METHOD send.
    io_response->set_status( i_code = iv_code i_reason = iv_reason ).
    io_response->set_content_type( 'application/json' ).
    io_response->set_text( iv_json ).
  ENDMETHOD.

ENDCLASS.
