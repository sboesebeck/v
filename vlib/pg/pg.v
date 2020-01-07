module pg

#flag -lpq
#flag linux -I/usr/include/postgresql
#flag darwin -I/opt/local/include/postgresql11
#include <libpq-fe.h>

pub struct DB {
mut:
	conn &C.PGconn
}

pub struct Row {
pub mut:
	vals []string
}

struct C.PGResult { }

pub struct Config {
pub:
	host string
	user string
	password string
	dbname string
}

fn C.PQconnectdb(a byteptr) &C.PGconn
fn C.PQerrorMessage(voidptr) byteptr
fn C.PQgetvalue(voidptr, int, int) byteptr
fn C.PQstatus(voidptr) int
fn C.PQntuples(voidptr) int
fn C.PQnfields(voidptr) int
fn C.PQexec(voidptr) voidptr
fn C.PQexecParams(voidptr) voidptr

pub fn connect(config pg.Config) ?DB {
	conninfo := 'host=$config.host user=$config.user dbname=$config.dbname'
	conn := C.PQconnectdb(conninfo.str)
	status := C.PQstatus(conn)
	println("status=$status")
	if status != C.CONNECTION_OK {
		error_msg := C.PQerrorMessage(conn)
		return error ('Connection to a PG database failed: ' + string(error_msg))
	}
	return DB {conn: conn}
}

fn res_to_rows(res voidptr) []pg.Row {
	nr_rows := C.PQntuples(res)
	nr_cols := C.PQnfields(res)
	mut rows := []pg.Row
	for i := 0; i < nr_rows; i++ {
		mut row := Row{}
		for j := 0; j < nr_cols; j++ {
			val := C.PQgetvalue(res, i, j)
			row.vals << string(val)
		}
		rows << row
	}
	return rows
}

pub fn (db DB) q_int(query string) int {
	rows := db.exec(query)
	if rows.len == 0 {
		println('q_int "$query" not found')
		return 0
	}
	row := rows[0]
	if row.vals.len == 0 {
		return 0
	}
	val := row.vals[0]
	return val.int()
}

pub fn (db DB) q_string(query string) string {
	rows := db.exec(query)
	if rows.len == 0 {
		println('q_string "$query" not found')
		return ''
	}
	row := rows[0]
	if row.vals.len == 0 {
		return ''
	}
	val := row.vals[0]
	return val
}

pub fn (db DB) q_strings(query string) []pg.Row {
	return db.exec(query)
}

pub fn (db DB) exec(query string) []pg.Row {
	res := C.PQexec(db.conn, query.str)
	e := string(C.PQerrorMessage(db.conn))
	if e != '' {
		println('pg exec error:')
		println(e)
		return res_to_rows(res)
	}
	return res_to_rows(res)
}

fn rows_first_or_empty(rows []pg.Row) ?pg.Row {
	if rows.len == 0 {
		return error('no row')
	}
	return rows[0]
}

pub fn (db DB) exec_one(query string) ?pg.Row {
	res := C.PQexec(db.conn, query.str)
	e := string(C.PQerrorMessage(db.conn))
	if e != '' {
		return error('pg exec error: "$e"')
	}
	row := rows_first_or_empty( res_to_rows(res) )
	return row
}

//
pub fn (db DB) exec_param_many(query string, params []string) []pg.Row {
	mut param_vals := &byteptr( malloc( params.len * sizeof(byteptr) ) )
	for i := 0; i < params.len; i++ {
		param_vals[i] = params[i].str
	}
	res := C.PQexecParams(db.conn, query.str, params.len, 0, param_vals, 0, 0, 0)
	unsafe{ free(param_vals) }
	return db.handle_error_or_result(res, 'exec_param_many')
}  

pub fn (db DB) exec_param2(query string, param, param2 string) []pg.Row {
	mut param_vals := [2]byteptr
	param_vals[0] = param.str
	param_vals[1] = param2.str
	res := C.PQexecParams(db.conn, query.str, 2, 0, param_vals, 0, 0, 0)
	return db.handle_error_or_result(res, 'exec_param2')
}

pub fn (db DB) exec_param(query string, param string) []pg.Row {
	mut param_vals := [1]byteptr
	param_vals[0] = param.str
	res := C.PQexecParams(db.conn, query.str, 1, 0, param_vals, 0, 0, 0)
	return db.handle_error_or_result(res, 'exec_param')
}

fn (db DB) handle_error_or_result(res voidptr, elabel string) []pg.Row {
	e := string(C.PQerrorMessage(db.conn))
	if e != '' {
		println('pg $elabel error:')
		println(e)
		return res_to_rows(res)
	}
	return res_to_rows(res)
}
