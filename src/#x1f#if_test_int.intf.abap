INTERFACE /x1f/if_test_int
  PUBLIC.

  TYPES:
    BEGIN OF ty_test_int,
      id           TYPE sysuuid_x16,
      description  TYPE char100,
      created_on   TYPE dats,
      created_time TYPE tims,
      created_by   TYPE syuname,
      changed_on   TYPE dats,
      changed_time TYPE tims,
      changed_by   TYPE syuname,
    END OF ty_test_int,
    ty_test_int_t TYPE STANDARD TABLE OF ty_test_int WITH EMPTY KEY.

  METHODS list
    IMPORTING
      iv_id          TYPE sysuuid_x16 OPTIONAL
    RETURNING
      VALUE(rt_data) TYPE ty_test_int_t.

  METHODS create
    IMPORTING
      iv_description TYPE char100
    RETURNING
      VALUE(rs_data) TYPE ty_test_int.

  METHODS update
    IMPORTING
      iv_id           TYPE sysuuid_x16
      iv_description  TYPE char100
    RETURNING
      VALUE(rv_found) TYPE abap_bool.

ENDINTERFACE.
