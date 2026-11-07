extends RefCounted
class_name DiagnosticFormatter


static func format_error(error: ProgramDiagnostic) -> String:
	var result: String = "Traceback (most recent call last):\n" if error.is_runtime else ""
	result += "  File \"main\", line %d\n" % error.line
	result += "    " + error.source_line.replace("\t", "    ") + "\n"
	if not error.is_runtime:
		var prefix: String = error.source_line.left(maxi(error.column - 1, 0))
		result += "    " + " ".repeat(prefix.replace("\t", "    ").length()) + "^\n"
	return result + error.type + ": " + error.message
