class /X1F/CL_TEST_INT_001 definition
  public
  inheriting from /X1F/CL_WI_REST_BASE
  final
  create public .

  public section.
    interfaces /x1f/if_test_int_001.

  protected section.
    " table-agnostic hooks required by the base - just bridge to the interface
    methods read_all         redefinition.
    methods read_by_id       redefinition.
    methods create_from_json redefinition.
    methods update_from_json redefinition.

  private section.
    " accepts both UUID formats a client may send back: 36-char with hyphens
    " (C36) and 32-char hex (C32, the format XCO emits for a RAW16 field)
    methods to_uuid_x16
      importing iv_value       type string
      returning value(rv_uuid) type sysuuid_x16
      raising   cx_uuid_error.
ENDCLASS.



CLASS /X1F/CL_TEST_INT_001 IMPLEMENTATION.

  " ============================================================================
  " Hooks for the base (REST plumbing) - table-agnostic signatures
  " ============================================================================

  METHOD read_all.
    " CREATE DATA puts the table on the heap so the data ref stays valid
    " after the method returns (a REF #( local ) would dangle).
    DATA lr TYPE REF TO /x1f/if_test_int_001=>ty_rows.
    CREATE DATA lr.
    lr->* = /x1f/if_test_int_001~list( ).
    rr_data = lr.
  ENDMETHOD.

  METHOD read_by_id.
    DATA lr TYPE REF TO /x1f/if_test_int_001=>ty_rows.
    CREATE DATA lr.
    lr->* = /x1f/if_test_int_001~list( to_uuid_x16( iv_id ) ).
    rr_data = lr.
  ENDMETHOD.

  METHOD create_from_json.
    " POST body is a JSON ARRAY: [ { "description": "a" }, { "description": "b" } ]
    " XCO deserializes the array straight into an internal table.
    DATA lt_input TYPE /x1f/if_test_int_001=>ty_create_in_t.
    xco_cp_json=>data->from_string( iv_json )->write_to( REF #( lt_input ) ).

    DATA lr TYPE REF TO /x1f/if_test_int_001=>ty_rows.
    CREATE DATA lr.
    lr->* = /x1f/if_test_int_001~create_many( lt_input ).
    rr_data = lr.
  ENDMETHOD.

  METHOD update_from_json.
    DATA ls_input TYPE /x1f/if_test_int_001=>ty_create_in.
    xco_cp_json=>data->from_string( iv_json )->write_to( REF #( ls_input ) ).
    rv_found = /x1f/if_test_int_001~update(
                 iv_id          = to_uuid_x16( iv_id )
                 iv_description = ls_input-description ).
  ENDMETHOD.

  " ============================================================================
  " Table-specific business logic (the "definitions" the user wants down here)
  " ============================================================================

  METHOD /x1f/if_test_int_001~list.
    " explicit column list (no MANDT) so the result is unicode-compatible with ty_rows
    IF iv_id IS INITIAL.
      SELECT id, description, created_by, created_at, changed_by, changed_at
        FROM /x1f/test_int
        ORDER BY created_at DESCENDING
        INTO TABLE @rt_rows.
    ELSE.
      SELECT id, description, created_by, created_at, changed_by, changed_at
        FROM /x1f/test_int
        WHERE id = @iv_id
        INTO TABLE @rt_rows.
    ENDIF.
  ENDMETHOD.

  METHOD /x1f/if_test_int_001~create_many.
    DATA lt_db TYPE STANDARD TABLE OF /x1f/test_int.
    DATA lv_now TYPE timestampl.

    GET TIME STAMP FIELD lv_now.
    " cloud adaptation: sy-uname replaced with released cloud API
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    " build every wire row in place via a field symbol (no per-row work-area copy)
    LOOP AT it_input ASSIGNING FIELD-SYMBOL(<in>).
      APPEND INITIAL LINE TO rt_rows ASSIGNING FIELD-SYMBOL(<row>).
      <row>-id          = cl_system_uuid=>create_uuid_x16_static( ).
      <row>-description = <in>-description.
      <row>-created_by  = lv_user.
      <row>-created_at  = lv_now.
      <row>-changed_by  = lv_user.
      <row>-changed_at  = lv_now.
    ENDLOOP.

    " one name-based mapping of the whole table to the DB row type (fills MANDT gap),
    " then a SINGLE bulk INSERT - one DB round-trip for all rows.
    lt_db = CORRESPONDING #( rt_rows ).
    INSERT /x1f/test_int FROM TABLE @lt_db.
  ENDMETHOD.

  METHOD /x1f/if_test_int_001~update.
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

  METHOD to_uuid_x16.
    DATA(lv_value) = condense( iv_value ).
    CASE strlen( lv_value ).
      WHEN 36.
        cl_system_uuid=>convert_uuid_c36_static(
          EXPORTING uuid     = CONV sysuuid_c36( to_lower( lv_value ) )
          IMPORTING uuid_x16 = rv_uuid ).
      WHEN 32.
        cl_system_uuid=>convert_uuid_c32_static(
          EXPORTING uuid     = CONV sysuuid_c32( to_upper( lv_value ) )
          IMPORTING uuid_x16 = rv_uuid ).
      WHEN OTHERS.
        RAISE EXCEPTION TYPE cx_uuid_error.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
