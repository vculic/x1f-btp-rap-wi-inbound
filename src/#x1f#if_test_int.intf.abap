INTERFACE /x1f/if_test_int
  PUBLIC.

  TYPES:
    BEGIN OF ty_test_int,
      id           TYPE sysuuid_x16,
      description  TYPE /x1f/test_desc,
      created_by   TYPE abp_creation_user,
      created_at   TYPE abp_creation_tstmpl,
      changed_by   TYPE abp_lastchange_user,
      changed_at   TYPE abp_lastchange_tstmpl,
    END OF ty_test_int,
    ty_test_int_t TYPE STANDARD TABLE OF ty_test_int WITH EMPTY KEY.

  METHODS list
    IMPORTING
      iv_id          TYPE sysuuid_x16 OPTIONAL
    RETURNING
      VALUE(rt_data) TYPE ty_test_int_t.

  METHODS create
    IMPORTING
      iv_description TYPE /x1f/test_desc
    RETURNING
      VALUE(rs_data) TYPE ty_test_int.

  METHODS update
    IMPORTING
      iv_id           TYPE sysuuid_x16
      iv_description  TYPE /x1f/test_desc
    RETURNING
      VALUE(rv_found) TYPE abap_bool.

ENDINTERFACE.
