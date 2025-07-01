module main

import strings

fn substr_with_runes(str string, start int, end int) string {
	r := str.runes()
	mut sb := strings.new_builder(end - start)
	for i in start .. end {
		if i >= r.len {
			break
		}
		sb.write_rune(r[i])
	}
	return sb.str()
}
