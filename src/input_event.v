module main

import term.ui as tui

fn event(e &tui.Event, mut app App) {
	if e.typ == .key_down {
		match e.code {
			.tab {
				keyboard_tab(mut app, e.modifiers)
			}
			.up {
				keyboard_up(mut app)
			}
			.down {
				keyboard_down(mut app)
			}
			.left {
				keyboard_left(mut app)
			}
			.right {
				keyboard_right(mut app)
			}
			32...126 { // most alpha
				// BUG: Windows always send .ctrl modifier
				$if windows {
					keyboard_alpha(mut app, e.ascii.ascii_str())
				} $else {
					if e.modifiers == .ctrl {
						if e.code == .k {
							app.sql_statement = ''
							app.cursor_location.set(layout['sql']['input_x'], layout['sql']['input_y'])
						}
					} else {
						keyboard_alpha(mut app, e.ascii.ascii_str())
					}
				}
			}
			.enter {
				keyboard_enter(mut app)
			}
			.backspace {
				keyboard_backspace(mut app)
			}
			.escape {
				exit(0)
			}
			.f4 {
				keyboard_f4(mut app)
			}
			.f5 {
				keyboard_f5(mut app)
			}
			else {}
		}
	}

	app.redraw = true
}

fn keyboard_tab(mut app App, m tui.Modifiers) {
	if m.has(.shift) {
		app.active_view = app.active_view.prev()
	} else {
		app.active_view = app.active_view.next()
	}
}

fn keyboard_up(mut app App) {
	match app.active_view {
		.table_list {
			app.table_list.move(.up, 1)
		}
		.result {
			app.result.move(.up, 1)
		}
		else {}
	}
}

fn keyboard_down(mut app App) {
	match app.active_view {
		.table_list {
			app.table_list.move(.down, 1)
		}
		.result {
			app.result.move(.down, 1)
		}
		else {}
	}
}

fn keyboard_left(mut app App) {
	match app.active_view {
		.table_list {
			app.table_list.move(.left, 1)
		}
		.sql {
			if app.cursor_location.x > layout['sql']['input_x'] {
				app.cursor_location.x -= 1
			}
		}
		.result {
			app.result.move(.left, 1)
		}
	}
}

fn keyboard_right(mut app App) {
	match app.active_view {
		.table_list {
			app.table_list.move(.right, 1)
		}
		.sql {
			if app.cursor_location.x < layout['sql']['input_x'] + app.sql_statement.len {
				app.cursor_location.x += 1
			}
		}
		.result {
			app.result.move(.right, 1)
		}
	}
}

fn keyboard_alpha(mut app App, alpha string) {
	if app.active_view != .sql {
		return
	}

	rel_cur := app.cursor_location.x - layout['sql']['input_x'] - 1
	left := app.sql_statement.substr(0, rel_cur + 1)
	right := app.sql_statement.substr(rel_cur + 1, app.sql_statement.len)

	app.sql_statement = '${left}${alpha}${right}'
	app.cursor_location.move(.right)
}

fn keyboard_backspace(mut app App) {
	if app.active_view != .sql {
		return
	}

	rel_cur := app.cursor_location.x - layout['sql']['input_x'] - 1
	if rel_cur < 0 {
		return
	}

	left := app.sql_statement.substr(0, rel_cur)
	right := app.sql_statement.substr(rel_cur + 1, app.sql_statement.len)
	app.sql_statement = '${left}${right}'
	app.cursor_location.move(.left)
}

fn keyboard_enter(mut app App) {
	match app.active_view {
		.table_list {
			app.table_list.rows.current_index = app.table_list.rows.hover_index
			app.load_table(app.table_list.data[app.table_list.rows.current_index])
			if app.db.data.len > 0 {
				app.active_view = .result
			}
		}
		.sql {
			app.exec_sql(app.sql_statement)
		}
		else {}
	}
}

fn keyboard_f4(mut app App) {
	// Prev Page
	if app.active_view == .result && app.db.page_offset > 0 {
		app.db.page_offset--
		app.exec_sql(app.sql_statement)
	}
}

fn keyboard_f5(mut app App) {
	// Next Page
	if app.active_view == .result && app.db.has_next_page {
		app.db.page_offset++
		app.exec_sql(app.sql_statement)
	}
}
