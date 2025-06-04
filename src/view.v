module main

enum Direction {
	up
	down
	left
	right
}

struct Visible {
mut:
	visible_data  []string
	visible_start int
	visible_max   int
	current_index int
	hover_index   int
}

struct View {
mut:
	data []string
	rows Visible
	cols Visible
}

fn (mut v View) reset() {
	v = View{}
}

fn (mut v View) calc_visible_data() {
	v.rows.visible_data = []string{}
	// CALC ROWS TO SHOW
	for i in v.rows.visible_start .. (v.rows.visible_start + v.rows.visible_max) {
		if i < v.data.len {
			// allow for horizontal scrolling if needed
			row_data := if utf8_str_visible_length(v.data[i]) > v.cols.visible_start +
				v.cols.visible_max {
				substr_with_runes(v.data[i], v.cols.visible_start, v.cols.visible_start +
					v.cols.visible_max)
			} else if utf8_str_visible_length(v.data[i]) > v.cols.visible_max
				&& v.cols.visible_start < utf8_str_visible_length(v.data[i]) - 1 {
				substr_with_runes(v.data[i], v.cols.visible_start, utf8_str_visible_length(v.data[i]))
			} else {
				v.data[i]
			}

			v.rows.visible_data << row_data
		}
	}
}

fn (mut v View) move(dir Direction, amount int) {
	match dir {
		.up {
			if v.rows.hover_index > 0 {
				// MOVE HOVER
				v.rows.hover_index -= amount
				if v.rows.hover_index < v.rows.visible_start {
					// SCROLL
					v.rows.visible_start -= amount
				}
			}
		}
		.down {
			if v.rows.hover_index < v.data.len - 1 {
				// MOVE HOVER
				v.rows.hover_index += amount
				if v.rows.hover_index >= v.rows.visible_max
					&& (v.rows.hover_index - v.rows.visible_max) >= v.rows.visible_start {
					// SCROLL
					v.rows.visible_start += amount
				}
			}
		}
		.right {
			if v.cols.visible_start < v.cols.visible_max - amount {
				v.cols.visible_start += amount
			}
		}
		.left {
			if v.cols.visible_start >= amount {
				v.cols.visible_start -= amount
			}
		}
	}
}

enum ActiveView {
	table_list
	sql_view
	result
}

fn (a ActiveView) next() ActiveView {
	match a {
		.table_list {
			return .sql_view
		}
		.sql_view {
			return .result
		}
		.result {
			return .table_list
		}
	}
}

fn (a ActiveView) prev() ActiveView {
	match a {
		.table_list {
			return .result
		}
		.sql_view {
			return .table_list
		}
		.result {
			return .sql_view
		}
	}
}
