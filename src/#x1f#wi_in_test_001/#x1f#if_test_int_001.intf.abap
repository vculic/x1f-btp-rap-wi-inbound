INTERFACE /x1f/if_test_int_001
  PUBLIC.

  " All table-specific DEFINITIONS live here (and in the subclass), never in the
  " abstract base. To expose another table: copy this interface + its subclass,
  " change the types and SQL, keep /X1F/CL_WI_REST_BASE untouched.

  TYPES:
    "! One row as exposed on the wire - deliberately WITHOUT the client field,
    "! so MANDT never leaks into the JSON payload.
    BEGIN OF ty_row,
      id           TYPE sysuuid_x16,
      description  TYPE /x1f/test_desc,
      created_by   TYPE abp_creation_user,
      created_at   TYPE abp_creation_tstmpl,
      changed_by   TYPE abp_lastchange_user,
      changed_at   TYPE abp_lastchange_tstmpl,
    END OF ty_row,
    ty_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

  TYPES:
    "! Input payload for POST - only the client-writable fields.
    BEGIN OF ty_create_in,
      description TYPE /x1f/test_desc,
    END OF ty_create_in,
    ty_create_in_t TYPE STANDARD TABLE OF ty_create_in WITH EMPTY KEY.

  METHODS list
    IMPORTING iv_id          TYPE sysuuid_x16 OPTIONAL
    RETURNING VALUE(rt_rows) TYPE ty_rows.

  "! Bulk create - inserts every input row in a SINGLE database round-trip.
  METHODS create_many
    IMPORTING it_input       TYPE ty_create_in_t
    RETURNING VALUE(rt_rows) TYPE ty_rows
    RAISING   cx_uuid_error.

  METHODS update
    IMPORTING iv_id           TYPE sysuuid_x16
              iv_description  TYPE /x1f/test_desc
    RETURNING VALUE(rv_found) TYPE abap_bool.

ENDINTERFACE.
