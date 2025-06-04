module main

import math

const min_padding = 2

const box = {
	'top_right':    '╮'
	'top_left':     '╭'
	'bottom_right': '╯'
	'bottom_left':  '╰'
	'horizontal':   '─'
	'vertical':     '│'
}

struct Cursor {
mut:
	x int
	y int
}

fn (mut c Cursor) set(x int, y int) {
	c.x = x
	c.y = y
}

fn (mut c Cursor) move(dir Direction) {
	match dir {
		.left {
			c.x--
		}
		.right {
			c.x++
		}
		else {}
	}
}

fn (mut c Cursor) set_line_end(mut app App) {
	c.set(layout['sql']['input_x'] + app.sql_statement.len, layout['sql']['input_y'])
}

fn (mut app App) draw_box(x1 int, y1 int, x2 int, y2 int, title string) {
	width := x2 - x1
	bar := box['horizontal'].repeat(width - 2)
	// HEADER
	app.tui.draw_text(x1, y1, '${box['top_left']}${bar}${box['top_right']}')
	// BODY
	for i in y1 + 1 .. y2 {
		app.tui.draw_text(x1, i, box['vertical'])
		app.tui.draw_text(x2 - 1, i, box['vertical'])
	}
	// FOOTER
	app.tui.draw_text(x1, y2, '${box['bottom_left']}${bar}${box['bottom_right']}')
	// TITLE
	if title.len > 0 {
		app.tui.draw_text(x1 + 1, y1, title)
	}
}

fn (mut app App) draw_table_list() {
	app.table_list.cols.visible_max = (layout['table_list']['x2'] - layout['table_list']['x1']) - 2
	app.table_list.rows.visible_max = (app.tui.window_height - layout['table_list']['y1']) - 2

	app.table_list.calc_visible_data()

	mut y := 0
	for i, table in app.table_list.rows.visible_data {
		if app.table_list.rows.current_index == app.table_list.rows.visible_start + i {
			app.tui.reset()
			app.tui.set_color(blue)
			app.tui.bold()
			if app.table_list.rows.hover_index == i {
				app.tui.set_color(black)
				app.tui.set_bg_color(blue)
			}
			app.tui.draw_text(layout['table_list']['x1'] + 1, y + layout['table_list']['y1'] + 1,
				'»${table}')
		} else if app.table_list.rows.hover_index == app.table_list.rows.visible_start + i {
			app.tui.reset()
			app.tui.set_bg_color(grey)
			app.tui.set_color(white)
			app.tui.draw_text(layout['table_list']['x1'] + 1, y + 2, '›${table}')
		} else {
			app.tui.reset()
			app.tui.draw_text(layout['table_list']['x1'] + 1, y + 2, '∙${table}')
		}
		y++
	}
}

fn (mut app App) draw_sql() {
	app.tui.reset()
	app.tui.draw_text(layout['sql']['input_x'], layout['sql']['input_y'], app.sql_statement)
	if app.active_view == .sql_view {
		app.tui.show_cursor()
	}
}

fn (mut app App) draw_result() {
	app.result.cols.visible_max = (app.tui.window_width - layout['result']['x1']) - 2
	app.result.rows.visible_max = (app.tui.window_height - layout['result']['row_start_y']) - 1

	app.result.calc_visible_data()

	// TABLE HEADINGS
	x, y := layout['result']['heading_x'], layout['result']['heading_y']
	app.tui.reset()
	app.tui.bold()

	mut col_data := ''
	for i, col in app.db.table_cols {
		col_data += app.col_with_padding(col.name.to_upper(), i)
	}

	// allow for horizontal scrolling if needed
	col_str := if col_data.len > app.result.cols.visible_start + app.result.cols.visible_max {
		substr_with_runes(col_data, app.result.cols.visible_start, app.result.cols.visible_start +
			app.result.cols.visible_max)
	} else if col_data.len > app.result.cols.visible_max
		&& app.result.cols.visible_start < col_data.len - 1 {
		substr_with_runes(col_data, app.result.cols.visible_start, col_data.len)
	} else {
		col_data
	}

	app.tui.draw_text(x, y, col_str)

	// TABLE ROWS
	if app.result.rows.visible_data.len == 0 {
		draw_branding(mut app)
	} else {
		app.tui.reset()
		app.tui.set_color(grey)
		row_start_x := layout['result']['row_start_x']
		row_start_y := layout['result']['row_start_y']

		for n, row in app.result.rows.visible_data {
			app.tui.reset()
			if app.result.rows.hover_index == n + app.result.rows.visible_start {
				app.tui.set_color(black)
				app.tui.set_bg_color(blue)
			}
			app.tui.draw_text(row_start_x, row_start_y + n, row)
		}
	}
}

fn (mut app App) draw_info_footer() {
	db_name := 'DB: ${app.db.path}'

	mut row_status := ''
	if app.active_view == .result {
		row := (app.db.page_offset * max_per_page) + app.result.rows.hover_index + 1
		mut total := '${(app.db.page_offset * max_per_page) + app.result.data.len}'
		if app.db.has_next_page {
			total = '${total}+'
		}
		row_status = '(Row: ${row}/${total})'
	}

	is_windows := $if windows { true } $else { false }
	mut instructions := '[TAB: Next Panel]  '
	instructions += if app.active_view == .table_list {
		'[ENTER: Load Table]'
	} else if app.active_view == .sql_view && !is_windows {
		'[ENTER: Execute SQL  Ctrl-K: Clear]'
	} else if app.active_view == .sql_view && is_windows {
		'[ENTER: Execute SQL]'
	} else if !app.db.custom_pagination {
		'[F4: Prev Page  F5: Next Page]'
	} else {
		''
	}
	instructions += '  [ESC: Quit]'

	version := 'v1.1'

	padding_size := math.max((app.tui.window_width - instructions.len) / 2, min_padding)

	// DB NAME
	app.tui.reset()
	app.tui.draw_text(1, app.tui.window_height, '${db_name}')

	// ERROR
	if app.error.len > 0 {
		app.tui.set_bg_color(red)
		app.tui.draw_text(db_name.len + 3, app.tui.window_height, '<${app.error}>')
	}

	// INSTRUCTIONS
	app.tui.set_bg_color(grey)
	app.tui.set_color(black)
	app.tui.draw_text(padding_size, app.tui.window_height, '${instructions}')

	app.tui.reset()

	// ROW STATUS
	app.tui.draw_text((app.tui.window_width / 2) + padding_size, app.tui.window_height,
		'${row_status}')

	// VERSION
	app.tui.draw_text(app.tui.window_width - version.len, app.tui.window_height, '${version}')
}

fn draw_branding(mut app App) {
	app.tui.reset()
	app.tui.set_color(blue)
	app.tui.draw_text(app.tui.window_width - 40, app.tui.window_height - 7, '███████╗███████╗ ██████╗ ██╗')
	app.tui.draw_text(app.tui.window_width - 40, app.tui.window_height - 6, '╚══███╔╝██╔════╝██╔═══██╗██║      ██╗')
	app.tui.draw_text(app.tui.window_width - 40, app.tui.window_height - 5, '  ███╔╝ █████╗  ██║   ██║██║    ██████╗')
	app.tui.draw_text(app.tui.window_width - 40, app.tui.window_height - 4, ' ███╔╝  ██╔══╝  ██║▄▄ ██║██║    ╚═██╔═╝')
	app.tui.draw_text(app.tui.window_width - 40, app.tui.window_height - 3, '███████╗███████╗╚██████╔╝███████╗ ╚═╝')
	app.tui.draw_text(app.tui.window_width - 40, app.tui.window_height - 2, '╚══════╝╚══════╝ ╚══▀▀═╝ ╚══════╝')
}
