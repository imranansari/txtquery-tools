JsOsaDAS1.001.00bplist00�Vscript_
function run() {	lst = ["today", "a", "thing", "funny", "happened", "to", "me"];	lst.sort(
		function (a, b) { 			var d = a.length - b.length; // Shorter items first			return d ? d : (Number(a < b) ? -1 : 1); // by alpha if same length		}
	);	return lst;}                               jscr  ��ޭ