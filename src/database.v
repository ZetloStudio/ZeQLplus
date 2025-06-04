module main

import db.sqlite
import strings

const max_per_page = 100

struct DB {
	path string
mut:
	table_cols        []Column
	data              []sqlite.Row
	has_next_page     bool
	page_offset       int
	custom_pagination bool
}

struct Column {
	name     string
	datatype string
	notnull  bool
	pk       bool
}

fn (mut app App) load_table_list() {
	app.table_list.data = []
	mut conn := sqlite.connect(app.db.path) or { panic(err) }
	defer {
		conn.close() or { panic(err) }
	}

	data := conn.exec("SELECT name FROM sqlite_master WHERE type='table'") or {
		app.error = err.msg()
		return
	}
	for table in data {
		app.table_list.data << table.vals[0]
	}

	app.table_list.data.sort()
}

fn (mut app App) load_table(table_name string) {
	app.db.page_offset = 0
	app.exec_sql('SELECT * FROM ${table_name};')
}

fn (mut app App) exec_sql(sql_query string) ? {
	if sql_query.len == 0 {
		return
	}

	app.error = ''
	app.db.data = []
	mut conn := sqlite.connect(app.db.path) or { panic(err) }
	defer {
		conn.close() or { panic(err) }
	}

	query := enforce_limit(mut app, sql_query)
	data := conn.exec(query) or {
		app.error = err.msg()
		return
	}
	app.db.data = data

	get_query_columns(mut app, sql_query)
	app.calculate_col_widths()

	// SETUP DATA IN VIEW FROM DB TABLE
	app.result.reset()
	for row in app.db.data {
		mut sb := strings.new_builder(row.vals.len)
		for i in 0 .. row.vals.len {
			sb.write_string(app.col_with_padding(row.vals[i], i))
		}
		app.result.data << sb.str()
	}

	if sql_query.to_lower().starts_with('drop') || sql_query.to_lower().starts_with('create') {
		app.load_table_list()
	}

	app.db.has_next_page = if app.db.data.len == max_per_page { true } else { false }

	app.sql_statement = '${sql_query}'
	app.cursor_location.set_line_end(mut app)
	app.redraw = true
}

fn enforce_limit(mut app App, sql_query string) string {
	mut parts := sql_query.to_lower().trim(';').split(' ')

	// Only apply limit to select queries
	if parts.index('select') != 0 {
		return sql_query
	}

	has_limit_index := parts.index('limit')
	has_limit := if parts.len > has_limit_index + 1 { true } else { false }
	has_offset_index := parts.index('offset')
	has_offset := if parts.len > has_offset_index + 1 { true } else { false }

	if has_limit_index > 0 || has_offset_index > 0 {
		app.db.custom_pagination = true
		return sql_query
	}

	app.db.custom_pagination = false

	// LIMIT
	if has_limit && has_limit_index >= 0 && parts[has_limit_index + 1].int() > max_per_page {
		parts[has_limit_index + 1] = max_per_page.str()
	} else if has_limit_index == -1 {
		parts << 'limit ${max_per_page}'
	}

	// OFFSET
	if has_offset_index >= 0 && !has_offset {
		parts[has_offset_index + 1] = '${app.db.page_offset * max_per_page}'
	} else if has_offset_index == -1 {
		parts << 'offset ${(app.db.page_offset * max_per_page)}'
	}

	return parts.join(' ')
}

fn get_query_columns(mut app App, sql_query string) {
	app.db.table_cols = []

	if sql_query.to_lower().starts_with('select * from') {
		// They want the whole table, work out the table name to get all columns
		s := sql_query.split(' ')
		if s.len >= 3 {
			get_table_columns(mut app, s[3].trim(';'))
		}
	} else if sql_query.to_lower().starts_with('select ') {
		// NOTE: this is just a simple split of any words separated by ','
		// between SELECT & FROM - will only work with simple queries
		from_idx := sql_query.to_lower().index('from') or {
			app.error = 'Invalid SQL: no FROM clause'
			return
		}
		all_cols := sql_query.substr('select'.len, from_idx)
		cols := all_cols.split(',')

		for col in cols {
			alias := col.split(' as ')
			col_name := if alias.len == 2 {
				alias[1]
			} else {
				col
			}

			c := Column{
				name:     col_name.trim_space()
				datatype: 'text'
				notnull:  false
				pk:       false
			}

			app.db.table_cols << c
		}
	}
}

fn get_table_columns(mut app App, table_name string) {
	mut conn := sqlite.connect(app.db.path) or { panic(err) }
	defer {
		conn.close() or { panic(err) }
	}

	data := conn.exec('PRAGMA table_info(${table_name})') or {
		app.error = err.msg()
		return
	}
	for row in data {
		col := Column{
			name:     row.vals[1]
			datatype: row.vals[2]
			notnull:  row.vals[3] == '1'
			pk:       row.vals[5] == '1'
		}
		app.db.table_cols << col
	}
}
