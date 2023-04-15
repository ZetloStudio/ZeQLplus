module main

const col_spacer = 2

const layout = {
	'table_list': {
		'x1': 1
		'y1': 1
		'x2': 25
		'y2': 25
	}
	'sql':        {
		'x1':      26
		'y1':      1
		'x2':      50
		'y2':      3
		'input_x': 29
		'input_y': 2
	}
	'result':     {
		'x1':          26
		'y1':          4
		'x2':          50
		'y2':          25
		'heading_x':   28
		'heading_y':   5
		'row_start_x': 28
		'row_start_y': 6
	}
}

fn (mut app App) draw_layout() {
	// TABLE LIST
	app.tui.reset()
	if app.active_view == .table_list {
		app.tui.set_color(blue)
	}
	app.draw_box(layout['table_list']['x1'], layout['table_list']['y1'], layout['table_list']['x2'],
		app.tui.window_height - 1, 'Tables')

	// SQL
	app.tui.reset()
	if app.active_view == .sql {
		app.tui.set_color(blue)
	}
	app.draw_box(layout['sql']['x1'], layout['sql']['y1'], app.tui.window_width, layout['sql']['y2'],
		'SQL')
	app.tui.draw_text(27, 2, '>')

	// RESULT
	app.tui.reset()
	if app.active_view == .result {
		app.tui.set_color(blue)
	}
	app.draw_box(layout['result']['x1'], layout['result']['y1'], app.tui.window_width,
		app.tui.window_height - 1, 'Result')

	app.draw_info_footer()
}

fn (mut app App) calculate_col_widths() {
	for i, _ in app.col_widths {
		app.col_widths.delete(i)
	}
	// MAX LENGTH COLUMN HEADINGS
	for i, col in app.db.table_cols {
		length := col.name.len
		if length > app.col_widths[i] {
			app.col_widths[i] = length
		}
	}
	// MAX LENGTH TABLE COLUMN DATA
	for row in app.db.data {
		for i, val in row.vals {
			length := utf8_str_visible_length(val)
			if length > app.col_widths[i] {
				app.col_widths[i] = length
			}
		}
	}
}

fn (mut app App) col_with_padding(val string, col_index int) string {
	padding := (app.col_widths[col_index] + col_spacer) - utf8_str_visible_length(val)
	return val + ' '.repeat(padding)
}
