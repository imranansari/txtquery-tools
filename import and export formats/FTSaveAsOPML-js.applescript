function run() {
	'use strict';
	/* jshint multistr: true */
	var pTitle = "FT save as OPML",
		pVer = "0.5",
		pAuthor = "Rob Trew",
		pSite = "https://github.com/RobTrew/txtquery-tools",
		pComment = "\
			- Preserves the FoldingText outlining expansion state in the OPML.\
			- FoldingText @key(value) pairs become OPML attributes with string values\
			- FoldingText @tags with no value → OPML attributes with value 1\
			- each <outline> includes a textStart property (offset into FT file)\
		",
		pblnDebug = 0;

	var appSA = Application.currentApplication();
	appSA.includeStandardAdditions = true;


	//OPTIONS: 

	//Export the whole document, or just the subtree(s) of any selected line(s) ?
	var pblnWholeDoc = true;

	// Default folder for Save As dialog ?
	//var pOutFolder = appSA.pathTo('desktop');
	var pOutFolder = null;
	// or e.g.  
	// 	var pOutFolder=Path("/Users/houthakker/docs")


	// FoldingText code	(to be passed as string, with options, to FT.evaluate() ...)	
	var fnScript =
		function (editor, options) {
			// FoldingText code here

			// FIND THE ROOT NODES AMONG THE SELECTED LINES
			// (Ignoring any children of lines already seen)
			function selectedRoots() {
				var lstRoots = [],
					lstSeen = [];

				editor.selectedRange().forEachNodeInRange(function (oNode) {
					if (oNode.type() !== 'empty') {
						if (lstSeen.indexOf(oNode.parent.id) === -1) lstRoots.push(oNode);
						lstSeen.push(oNode.id);
					}
				});
				return lstRoots;
			}

			// Intermediate JSO format used in various scripts
			// nodeNest(lstNodes) [FTNode] → [{text:strText, nest:[<recursive>, , ]},fold]
			function textNest(lstNodes, oParent) {
				var lstNest = [],
					lstKeys, dctKeyVal,
					dctNode, oNode, dctTags, strKey, k;

				for (var i = 0, lng = lstNodes.length; i < lng; i++) {
					oNode = lstNodes[i];
					if (oNode.type() !== 'empty') {
						dctNode = {
							text: oNode.text(),
							posn: oNode.lineTextStart(),
							type: oNode.type(),
							parent: oParent
						};

						dctTags = oNode.tags();
						for (k in dctTags) { // ie only if object not empty
							dctNode.tags = dctTags;
							break; // one test only - no loop
						}

						if (oNode.hasChildren()) {
							dctNode.fold = editor.isCollapsed(oNode);
							dctNode.nest = textNest(oNode.children(), oNode);
						}
						lstNest.push(dctNode);
					}
				}
				return lstNest;
			}


			// TRANSLATE A SET OF ROOTS AND THEIR DESCENDANTS INTO OPML
			// Input format [{text:'', nest:[<recursive>], tags:{}, fold:false}]
			function opmlTranslation(lstRoots, strTitle) {

				var lstOPMLHead = [
						'<?xml version=\"1.0\" encoding=\"utf-8\"?>',
						'<opml version=\"1.0\">',
						'  <head>',
						'    <title>' + strTitle + '</title>',
						'    <expansionState>'
					],
					lstOPMLPostExpand = [
						'</expansionState>',
						'  </head>',
						'  <body>\n'
					],
					lstOPMLTail = [
						'  </body>',
						'</opml>'
					],
					strNodeStart = '<outline text=\"',
					strLeafClose = '/>\n',
					strParentClose = '>\n',
					strOutlineClose = '</outline>\n',
					strHead = lstOPMLHead.join('\n'),
					strTail = lstOPMLTail.join('\n'),
					strOutline = '',
					strOPML, lstOPML,
					lngRoots = lstRoots.length,
					i,
					lstFolds = [],
					iLine = 0;

				// WRITE OUT A LIST OF PEER NODES AS OPML, RECURSING WITH THEIR CHILDREN
				function opmlOutline(lstNest, strIndent, blnHidden) {
					var strOut = '',
						strDeeper = strIndent + '  ',
						blnCollapsed = blnHidden,
						dctTags, lstChiln, dctNode, oChild,
						strKey;

					for (var i = 0, lng = lstNest.length; i < lng; i++) {
						dctNode = lstNest[i];
						// text, offset into source doc, and type of node
						strOut = strOut + strIndent + strNodeStart + quoteAttr(dctNode.text) + '"';
						strOut = strOut + ' posn="' + dctNode.posn + '"';
						strOut = strOut + ' type="' + dctNode.type + '"';

						// further attributes
						dctTags = dctNode.tags;
						if (dctTags)
							for (strKey in dctTags)
								strOut = strOut + ' ' + strKey + '="' + quoteAttr(dctTags[strKey]) + '"';

						// recurse with any children before closing the <outline>
						if (dctNode.nest) {
							if (!blnHidden && !dctNode.fold)
								lstFolds.push(iLine); // Collect OPML ExpansionState digit
							else blnCollapsed = true;
							iLine++; // before the recursive descent

							strOut += strParentClose;
							strOut += opmlOutline(dctNode.nest, strDeeper, blnCollapsed);
							strOut = strOut + strIndent + strOutlineClose;
						} else {
							strOut += strLeafClose;
							iLine++;
						}

					}
					return strOut;
				}


				// WALK THROUGH THE TREE, BUILDING AN OPML OUTLINE STRING
				strOutline = opmlOutline(lstRoots, '    ', false);

				// ASSEMBLE THE HEADER,
				// INCLUDING THE EXPANSION DIGITS COLLECTED DURING RECURSION
				strHead = strHead + lstFolds.toString() + lstOPMLPostExpand.join('\n');

				// AND COMBINE HEAD BODY AND TAIL
				strOPML = [strHead, strOutline, strTail].join('');
				//strOPML = strOutline;
				return strOPML;
			}

			function quoteAttr(s) {
				return ('' + s) /* Forces the conversion to string. */
					.replace(/&/g, '&amp;') /* This MUST be the 1st replacement. */
					.replace(/\'/g, '&apos;') /* The 4 other predefined entities, required. */
					.replace(/\"/g, '&quot;')
					.replace(/</g, '&lt;')
					.replace(/>/g, '&gt;');
			}

			//////// FT MAIN

			var lstRoots, lstTextTree;

			// EXPORT WHOLE DOC ? OR JUST THE SELECTED LINE(S) AND ALL ITS/THEIR DESCENDANTS ?
			if (options.wholedoc)
				lstRoots = editor.tree().evaluateNodePath('/@type!=empty');
			else lstRoots = selectedRoots();

			lstTextTree = textNest(lstRoots, {
				type: 'root'
			});

			return opmlTranslation(
				lstTextTree, quoteAttr(options.title)
			);
		};

	//// run() FUNCTION(S)
	function chooseOutPath(oApp, oDocPath, strExtn) {
		var oFM = $.NSFileManager.defaultManager,
			pathLocn = pOutFolder, //module default
			pathOut = null,
			strName = ObjC.unwrap(oFM.displayNameAtPath(oDocPath.toString())),
			lstName = strName.split('.'),
			lngName = lstName.length,
			lstStem = lstName.slice(0, lngName - 1),
			strStem = lstName[0];

		if (!pathLocn || !oFM.fileExistsAtPathIsDirectory(pathLocn.toString(), null))
			pathLocn = oDocPath;

		// draft new name by substituting or affixing strExtn
		if (1 < lngName) {
			lstStem.push(strExtn);
			strName = lstStem.join('.');
		} else strName += '.' + strExtn;

		// show file name dialog
		oApp.activate();
		pathOut = oApp.chooseFileName({
			withPrompt: pTitle,
			defaultName: strName,
			defaultLocation: pathLocn
		});
		return [pathOut, strStem];
	}

	//////// run() MAIN
	var appFT = new Application("FoldingText"),
		//appSA=Application.currentApplication(),
		lstDocs = appFT.documents(),
		oDoc = lstDocs.length ? lstDocs[0] : null,
		fnProcess,
		oPath,
		strBaseName,
		strFTPath, pathOML = null,
		lstPathStem = [null, null],
		pathOPML = null,
		strOPML,
		nsOPML = null,
		strOPMLPath = '',
		strMsg = '';

	if (oDoc) {
		appFT.activate();
		appFT.includeStandardAdditions = true;

		// PROMPT FOR AN EXPORT FILE PATH
		oPath = oDoc.file();
		if (oPath) {
			lstPathStem = chooseOutPath(appFT, oPath, 'opml');
			pathOPML = lstPathStem[0];
			if (pathOPML) {

				fnProcess = (pblnDebug ? oDoc.debug : oDoc.evaluate);

				strOPML = fnProcess({
					script: fnScript.toString(),
					withOptions: {
						wholedoc: pblnWholeDoc,
						title: oPath.toString() //lstPathStem[1]
					}
				});

				if (strOPML) {
					strOPMLPath = pathOPML.toString();
					nsOPML = $.NSString.alloc.initWithUTF8String(strOPML);
					nsOPML.writeToFileAtomically(strOPMLPath, true);
				}
			}
		} else strMsg = "Save active file before exporting to OPML ...";
	} else strMsg = "No FoldingText documents open ...";

	if (strMsg) {
		var app = Application.currentApplication();
		app.includeStandardAdditions = true;
		app.displayDialog(strMsg, {
			withTitle: [pTitle, pVer].join('\t'),
			buttons: ["OK"],
			defaultButton: "OK"
		});
		return false;
	}
	return "Saved to " + strOPMLPath;
}