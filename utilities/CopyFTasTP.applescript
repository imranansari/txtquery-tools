property pTitle : "Copy from FoldingText in TASKPAPER format"

	
	function(editor, options) {
	
		// HOW MANY TABS WILL TASKPAPER NEED FOR THIS LINE ?
		function nestLevel(oNode) {
			var lngLevel=0;
			while (oNode.parent) {
				lngLevel++;
				oNode = oNode.parent;
			}
			return lngLevel;
		}
	
		// GET THE SELECTED LINES
		var lstNodes = editor.selectedRange().nodesInRange(),
			lstLines=[], varNode, strLine, dctTags, lstTags, varTag, strValue;
	
		// AND ADJUST TAB PREFIXES AND COLON SUFFIXES/INFIXES (BEFORE TAGS) 
		lstNodes.forEach(function (varNode) {
			if (varNode.type() !== 'heading')
				strLine = varNode.line().trim();
			else {
				// INSERT A COLON (BEFORE ANY TAGS) TO MARK EACH HASH HEADING AS A TP PROJECT
				strLine = varNode.text() + ': ';
				dctTags = varNode.tags(); lstTags = [];
				for (varTag in dctTags) {
					strValue = dctTags[varTag];
					if (strValue) lstTags.push(['@',varTag,'(',strValue,')'].join(''));
					else lstTags.push('@' + varTag);
				}
				if (lstTags.length) strLine += lstTags.join(' ');
			}
			
			// PREPEND EACH LINE WITH THE NUMBER OF TABS THAT MATCHES THE NESTING LEVEL
			lstLines.push([Array(nestLevel(varNode)).join('\\t'), strLine].join(''));
		});
		return lstLines.join('\\n');
	}

"