module main

import term.ui as tui
import os

struct App {
mut:
	tui             &tui.Context = unsafe { nil }
	db              DB
	cursor_location Cursor = Cursor{layout['sql']['input_x'], layout['sql']['input_y']}
	active_view     ActiveView
	table_list      View
	result          View
	col_widths      map[int]int
	sql_statement   string
	redraw          bool = true
	error           string
}

fn init(mut app App) {
	app.tui.set_window_title('ZeQL+')
	app.load_table_list()
	app.active_view = .table_list
}

fn frame(mut app App) {
	if !app.redraw {
		return
	}

	app.tui.clear()
	app.tui.hide_cursor()

	app.draw_table_list()
	app.draw_sql()
	app.draw_result()
	app.draw_layout()

	app.tui.reset()
	app.tui.set_cursor_position(app.cursor_location.x, app.cursor_location.y)
	app.tui.flush()

	app.redraw = false
}

fn main() {
	if os.args.len < 2 {
		println('Usage: zeql <database_filename>')
		return
	}
	path := os.args[1]
	if !os.is_file(path) {
		println('Can\'t find file: ${path}')
		exit(1)
	}

	mut app := &App{
		db: DB{
			path: path
		}
	}

	app.tui = tui.init(
		init_fn:   init
		user_data: app
		event_fn:  event
		frame_fn:  frame
	)

	app.tui.run()!
}
