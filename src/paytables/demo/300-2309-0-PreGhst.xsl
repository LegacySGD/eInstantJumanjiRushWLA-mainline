<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:x="anything">
	<xsl:namespace-alias stylesheet-prefix="x" result-prefix="xsl" />
	<xsl:output encoding="UTF-8" indent="yes" method="xml" />
	<xsl:include href="../utils.xsl" />

	<xsl:template match="/Paytable">
		<x:stylesheet version="1.0" xmlns:java="http://xml.apache.org/xslt/java" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			exclude-result-prefixes="java" xmlns:lxslt="http://xml.apache.org/xslt" xmlns:my-ext="ext1" extension-element-prefixes="my-ext">
			<x:import href="HTML-CCFR.xsl" />
			<x:output indent="no" method="xml" omit-xml-declaration="yes" />

			<!-- TEMPLATE Match: -->
			<x:template match="/">
				<x:apply-templates select="*" />
				<x:apply-templates select="/output/root[position()=last()]" mode="last" />
				<br />
			</x:template>

			<!--The component and its script are in the lxslt namespace and define the implementation of the extension. -->
			<lxslt:component prefix="my-ext" functions="formatJson,retrievePrizeTable,getType">
				<lxslt:script lang="javascript">
					<![CDATA[
					var debugFeed = [];
					var debugFlag = false;
					// Format instant win JSON results.
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function formatJson(jsonContext, translations, prizeTable, prizeValues, prizeNamesDesc)
					{
						var scenario             = getScenario(jsonContext);
						var scenarioWinNums      = scenario.split('|')[0].split(',');
						var scenarioYourNums     = scenario.split('|')[1].split(':');
						var scenarioBonus1       = scenario.split('|')[2];
						var scenarioBonus2       = scenario.split('|')[3].split(',');
						var convertedPrizeValues = (prizeValues.substring(1)).split('|').map(function(item) {return item.replace(/\t|\r|\n/gm, "")} );
						var prizeNames           = (prizeNamesDesc.substring(1)).split(',');

						////////////////////
						// Parse scenario //
						////////////////////

						const iwNeighbours     = [0,-4,1,6,5,4,-1,-6,-5];
						const mgPrizesQty      = 20;
						const mgNumsQty        = 20;
						const mgPickerSymbsQty = 3;
						const mgMultiSymb      = 24;
						const mgMultiSymbsQty  = 3;
						const mgIWSymb         = 0;
						const keySymbs 		   = ['SM','IW1','IW2','IW3','IW4','P1','P2','P3','BS'];

						var arrWinNums    = [];
						var arrWinNumSet  = [];
						var arrYourNums   = [];
						var arrYourNum    = [];
						var objWinNum     = {};
						var objYourNum    = {};
						var mgPrizes      = [];
						var mgNums        = [];
						var mgPickerSymbs = []; 
						var winNumVal     = 0;
						var yourNumVal    = 0;
						var winNumIndex   = -1;
						var iwIndex       = -1;
						var iwNeighbour   = 0;
						var wins 		  = keySymbs.map(function(item) {return [];} );

						for (var mgPrizeIndex = 0; mgPrizeIndex < mgPrizesQty; mgPrizeIndex++) {mgPrizes.push(String.fromCharCode('A'.charCodeAt() + mgPrizeIndex));}

						for (var mgNumIndex = 0; mgNumIndex < mgNumsQty; mgNumIndex++) {mgNums.push(mgNumIndex + 1);}

						for (var mgPickerSymbIndex = 0; mgPickerSymbIndex < mgPickerSymbsQty; mgPickerSymbIndex++) {mgPickerSymbs.push(mgPickerSymbIndex + 21);}

						for (var winNumIndex = 0; winNumIndex < scenarioWinNums.length; winNumIndex++)
						{
							objWinNum = {iValue: 0, bMatched: false};

							winNumVal = parseInt(scenarioWinNums[winNumIndex], 10);

							objWinNum.iValue = winNumVal; 

							arrWinNums.push(objWinNum);
							arrWinNumSet.push(winNumVal);
						}

						for (var yourNumIndex = 0; yourNumIndex < scenarioYourNums.length; yourNumIndex++)
						{
							objYourNum = {iValue: 0, sPrize: '', bMatched: false, iIWIndex: -1, iPickerSymb: 0, bMultiSymb: false};

							arrYourNums.push(objYourNum);
						}

						for (var yourNumIndex = 0; yourNumIndex < scenarioYourNums.length; yourNumIndex++)
						{
							arrYourNum = scenarioYourNums[yourNumIndex].split(',');
							yourNumVal = parseInt(arrYourNum[0], 10);

							if (mgNums.indexOf(yourNumVal) != -1)
							{
								arrYourNums[yourNumIndex].iValue = yourNumVal;
								arrYourNums[yourNumIndex].sPrize = arrYourNum[1];
								
								winNumIndex = arrWinNumSet.indexOf(yourNumVal);

								if (winNumIndex != -1)
								{
									arrYourNums[yourNumIndex].bMatched = true;
									arrWinNums[winNumIndex].bMatched = true;

									wins[keySymbs.indexOf('SM')].push(yourNumIndex);
								}
							}
							else if (yourNumVal == mgIWSymb)
							{
								iwIndex++;

								arrYourNums[yourNumIndex].iIWIndex = iwIndex;
								arrYourNums[yourNumIndex].sPrize   = arrYourNum[1];

								wins[keySymbs.indexOf('IW' + (iwIndex+1).toString())].push(yourNumIndex);

								for (var neighbourIndex = 0; neighbourIndex < arrYourNum[2].length; neighbourIndex++)
								{
									iwNeighbour = iwNeighbours[arrYourNum[2][neighbourIndex]];

									arrYourNums[yourNumIndex + iwNeighbour].iIWIndex = iwIndex;

									wins[keySymbs.indexOf('IW' + (iwIndex+1).toString())].push(yourNumIndex + iwNeighbour);
								}
							}
							else if (yourNumVal == mgMultiSymb)
							{
								arrYourNums[yourNumIndex].bMultiSymb = true;

								wins[keySymbs.indexOf('BS')].push(yourNumIndex);
							}
							else if (mgPickerSymbs.indexOf(yourNumVal) != -1)
							{
								arrYourNums[yourNumIndex].iPickerSymb = yourNumVal - 20;

								wins[keySymbs.indexOf('P' + (yourNumVal-20).toString())].push(yourNumIndex);
							}
						}

						/////////////////////////
						// Currency formatting //
						/////////////////////////

						var bCurrSymbAtFront = false;
						var strCurrSymb      = '';
						var strDecSymb       = '';
						var strThouSymb      = '';

						function getCurrencyInfoFromTopPrize()
						{
							var topPrize               = convertedPrizeValues[0];
							var strPrizeAsDigits       = topPrize.replace(new RegExp('[^0-9]', 'g'), '');
							var iPosFirstDigit         = topPrize.indexOf(strPrizeAsDigits[0]);
							var iPosLastDigit          = topPrize.lastIndexOf(strPrizeAsDigits.substr(-1));
							bCurrSymbAtFront           = (iPosFirstDigit != 0);
							strCurrSymb 	           = (bCurrSymbAtFront) ? topPrize.substr(0,iPosFirstDigit) : topPrize.substr(iPosLastDigit+1);
							var strPrizeNoCurrency     = topPrize.replace(new RegExp('[' + strCurrSymb + ']', 'g'), '');
							var strPrizeNoDigitsOrCurr = strPrizeNoCurrency.replace(new RegExp('[0-9]', 'g'), '');
							strDecSymb                 = strPrizeNoDigitsOrCurr.substr(-1);
							strThouSymb                = (strPrizeNoDigitsOrCurr.length > 1) ? strPrizeNoDigitsOrCurr[0] : strThouSymb;
						}

						function getPrizeInCents(AA_strPrize)
						{
							return parseInt(AA_strPrize.replace(new RegExp('[^0-9]', 'g'), ''), 10);
						}

						function getCentsInCurr(AA_iPrize)
						{
							var strValue = AA_iPrize.toString();

							strValue = (strValue.length < 3) ? ('00' + strValue).substr(-3) : strValue;
							strValue = strValue.substr(0,strValue.length-2) + strDecSymb + strValue.substr(-2);
							strValue = (strValue.length > 6) ? strValue.substr(0,strValue.length-6) + strThouSymb + strValue.substr(-6) : strValue;
							strValue = (bCurrSymbAtFront) ? strCurrSymb + strValue : strValue + strCurrSymb;

							return strValue;
						}

						getCurrencyInfoFromTopPrize();

						///////////////
						// UI Config //
						///////////////

						const boxWidthKey   = 30;
						const boxWidthNum   = 60;
						const boxWidthPrize = 120;
						
						const colourBlack   = '#000000';
						const colourBlue    = '#99ccff';
						const colourCyan    = '#ccffff';
						const colourGreen   = '#99ff99';
						const colourLemon   = '#ffff99';
						const colourLilac   = '#ccccff';
						const colourLime    = '#ccff99';
						const colourNavy    = '#0000ff';						
						const colourOrange  = '#ffaa55';
						const colourPink    = '#ffcccc';
						const colourPurple  = '#cc99ff';
						const colourRed     = '#ff9999';						
						const colourScarlet = '#ff0000';
						const colourWhite   = '#ffffff';
						const colourYellow  = '#ffff00';

						const iwColours          = [colourRed, colourOrange, colourLemon, colourLime];
						const bonusColours       = [colourRed, colourOrange, colourLemon, colourLime, colourGreen, colourCyan, colourBlue, colourLilac, colourPurple, colourPink];
						const pickerBoxColour    = colourNavy;
						const multiBoxColour     = colourScarlet;
						const bonusTextColour    = colourYellow;
						const specialBoxColours  = [colourBlue, colourRed, colourOrange, colourLemon, colourLime, pickerBoxColour, pickerBoxColour, pickerBoxColour, multiBoxColour];
						const specialTextColours = [colourBlack, colourBlack, colourBlack, colourBlack, colourBlack, bonusTextColour, bonusTextColour, bonusTextColour, bonusTextColour];

						var boxColourStr  = '';
						var canvasIdStr   = '';
						var elementStr    = '';
						var textColourStr = '';
						var textStr1      = '';
						var textStr2      = '';

						var r = [];

						function showBox(A_strCanvasId, A_strCanvasElement, A_iBoxWidth, A_strBoxColour, A_strTextColour, A_strText1, A_strText2)
						{
							const boxHeightStd = 24;
							const boxMargin    = 1;
							const boxTextY2    = 40;

							var canvasCtxStr = 'canvasContext' + A_strCanvasElement;
							var canvasWidth  = A_iBoxWidth + 2 * boxMargin;
							var boxHeight    = (A_strText2 == '') ? boxHeightStd : 2 * boxHeightStd;
							var canvasHeight = boxHeight + 2 * boxMargin;
							var boxTextY1    = (A_strText2 == '') ? boxHeight / 2 + 3 : boxHeight / 2 - 6;
							var textSize1    = (A_strText2 == '') ? ((A_iBoxWidth == boxWidthKey) ? '14' : '16') : '24';

							r.push('<canvas id="' + A_strCanvasId + '" width="' + canvasWidth.toString() + '" height="' + canvasHeight.toString() + '"></canvas>');
							r.push('<script>');
							r.push('var ' + A_strCanvasElement + ' = document.getElementById("' + A_strCanvasId + '");');
							r.push('var ' + canvasCtxStr + ' = ' + A_strCanvasElement + '.getContext("2d");');
							r.push(canvasCtxStr + '.font = "bold ' + textSize1 + 'px Arial";');
							r.push(canvasCtxStr + '.textAlign = "center";');
							r.push(canvasCtxStr + '.textBaseline = "middle";');
							r.push(canvasCtxStr + '.strokeRect(' + (boxMargin + 0.5).toString() + ', ' + (boxMargin + 0.5).toString() + ', ' + A_iBoxWidth.toString() + ', ' + boxHeight.toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strBoxColour + '";');
							r.push(canvasCtxStr + '.fillRect(' + (boxMargin + 1.5).toString() + ', ' + (boxMargin + 1.5).toString() + ', ' + (A_iBoxWidth - 2).toString() + ', ' + (boxHeight - 2).toString() + ');');
							r.push(canvasCtxStr + '.fillStyle = "' + A_strTextColour + '";');
							r.push(canvasCtxStr + '.fillText("' + A_strText1 + '", ' + (A_iBoxWidth / 2 + boxMargin).toString() + ', ' + boxTextY1.toString() + ');');

							if (A_strText2 != '')
							{
								r.push(canvasCtxStr + '.font = "bold 12px Arial";');
								r.push(canvasCtxStr + '.fillText("' + A_strText2 + '", ' + (A_iBoxWidth / 2 + boxMargin).toString() + ', ' + boxTextY2.toString() + ');');
							}

							r.push('</script>');
						}

						/////////////////
						// Symbols Key //
						/////////////////

						var symbIndex   = -1;
						var symbDesc    = '';
						var symbSpecial = '';
						var isSymbMatch = false;
						var isIW        = false;
						var isPicker    = false;
						var isBonus     = false;

						r.push('<div style="float:left; margin-right:50px">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td colspan="4" style="padding-bottom:10px">' + getTranslationByName("titleSymbolsKey", translations) + '</td>');
						r.push('</tr>');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td style="padding-left:10px; padding-right:30px">' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td style="padding-left:10px">' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var rowIndex = 0; rowIndex < mgNumsQty / 2; rowIndex++)
						{
							r.push('<tr class="tablebody">');

							for (var colIndex = 0; colIndex < 2; colIndex++)
							{
								symbIndex   = colIndex * mgNumsQty / 2 + rowIndex;
								textStr1    = (symbIndex + 1).toString();
								canvasIdStr = 'cvsKeySymb' + textStr1;
								elementStr  = 'eleKeySymb' + textStr1;
								symbDesc    = 'symb' + textStr1;

								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, boxWidthKey, colourWhite, colourBlack, textStr1, '');

								r.push('</td>');
								r.push('<td style="padding-left:10px">' + getTranslationByName(symbDesc, translations) + '</td>');
							}

							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						/////////////////
						// Colours Key //
						/////////////////

						r.push('<div style="float:left">');
						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablehead">');
						r.push('<td colspan="2" style="padding-bottom:10px">' + getTranslationByName("titleColoursKey", translations) + '</td>');
						r.push('</tr>');
						r.push('<tr class="tablehead">');
						r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
						r.push('<td style="padding-left:10px">' + getTranslationByName("keyDescription", translations) + '</td>');
						r.push('</tr>');

						for (var specialIndex = 0; specialIndex < keySymbs.length; specialIndex++)
						{
							symbSpecial   = keySymbs[specialIndex];
							canvasIdStr   = 'cvsKeySymb' + symbSpecial;
							elementStr    = 'eleKeySymb' + symbSpecial;
							boxColourStr  = specialBoxColours[specialIndex];
							textColourStr = specialTextColours[specialIndex];
							isSymbMatch   = (symbSpecial == 'SM');
							isIW          = (symbSpecial.slice(0,2) == 'IW');
							isPicker      = (symbSpecial[0] == 'P');
							isBonus       = (symbSpecial == 'BS');
							textStr1      = (isIW) ? 'IW' : ((isSymbMatch) ? '#' : symbSpecial);

							if (isIW)
							{
								symbDesc = getTranslationByName("keyIW", translations) + ' (' + getTranslationByName("keyIWDesc", translations) + ' ' + specialIndex.toString() + ')';
							}
							else if (isPicker)
							{
								symbDesc = getTranslationByName("key" + symbSpecial, translations) + ' (' + getTranslationByName("keyPicker", translations) + ' ' + (specialIndex-4).toString() + ')';
							}
							else if (isSymbMatch || isBonus)
							{
								symbDesc = getTranslationByName("key" + symbSpecial, translations);
							};

							r.push('<tr class="tablebody">');
							r.push('<td align="center">');

							showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, textColourStr, textStr1, '');

							r.push('</td>');
							r.push('<td style="padding-left:10px">' + symbDesc + '</td>');
							r.push('</tr>');
						}

						r.push('</table>');
						r.push('</div>');

						///////////////
						// Main Game //
						///////////////

						const yourNumsPerRow = 5;

						var ynIndex       = -1;
						var symbQty       = 0;
						var doPickerBonus = false;
						var doMultiBonus  = false;
						var mgTotal       = 0;

						//////////////
						// Win Nums //
						//////////////

						r.push('<div style="clear:both">');
						r.push('<p><br>' + getTranslationByName("mainGame", translations).toUpperCase() + '</p>');
						r.push('<p>' + getTranslationByName("mgWinSymbs", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
						r.push('<tr class="tablebody">');

						for (var winNumIndex = 0; winNumIndex < arrWinNums.length; winNumIndex++)
						{
							canvasIdStr  = 'cvsWinSymb' + winNumIndex.toString();
							elementStr   = 'eleWinSymb' + winNumIndex.toString();
							boxColourStr = (arrWinNums[winNumIndex].bMatched) ? specialBoxColours[keySymbs.indexOf('SM')] : colourWhite;
							textStr1     = arrWinNums[winNumIndex].iValue.toString();

							r.push('<td align="center" style="padding-right:20px">');

							showBox(canvasIdStr, elementStr, boxWidthNum, boxColourStr, colourBlack, textStr1, '');

							r.push('</td>');
						}

						r.push('</tr>');
						r.push('</table>');
						r.push('</div>');

						///////////////
						// Your Nums //
						///////////////

						r.push('<p>' + getTranslationByName("mgYourSymbs", translations) + '</p>');

						r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

						for (var ynRow = 0; ynRow < arrYourNums.length / yourNumsPerRow; ynRow++)
						{
							r.push('<tr class="tablebody">');

							for (var ynCol = 0; ynCol < yourNumsPerRow; ynCol++)
							{
								symbIndex     = ynRow * yourNumsPerRow + ynCol;
								canvasIdStr   = 'cvsYourSymb' + symbIndex.toString();
								elementStr    = 'eleYourSymb' + symbIndex.toString();
								isSymbMatch   = arrYourNums[symbIndex].bMatched;
								isIW          = (arrYourNums[symbIndex].iIWIndex != -1);
								isPicker      = (arrYourNums[symbIndex].iPickerSymb != 0);
								isBonus       = arrYourNums[symbIndex].bMultiSymb;
								symbSpecial   = (isPicker) ? 'P' + arrYourNums[symbIndex].iPickerSymb.toString() : ((isBonus) ? 'BS' : ((isIW) ? 'IW' : ''));
								ynIndex       = (isSymbMatch) ? keySymbs.indexOf('SM') : ((isIW) ? arrYourNums[symbIndex].iIWIndex : ((isPicker || isBonus) ? keySymbs.indexOf(symbSpecial) : -1));
								boxColourStr  = (isSymbMatch) ? specialBoxColours[ynIndex] : ((isIW) ? iwColours[ynIndex] : ((isPicker || isBonus) ? specialBoxColours[ynIndex] : colourWhite));
								textColourStr = (isPicker || isBonus) ? specialTextColours[ynIndex] : colourBlack;
								textStr1      = (isPicker || isBonus || (isIW && arrYourNums[symbIndex].iValue == 0)) ? symbSpecial : arrYourNums[symbIndex].iValue.toString();
								textStr2      = (isPicker || isBonus) ? ' ' : convertedPrizeValues[getPrizeNameIndex(prizeNames, 'm' + arrYourNums[symbIndex].sPrize)];

								r.push('<td align="center" style="padding-right:20px">');

								showBox(canvasIdStr, elementStr, boxWidthPrize, boxColourStr, textColourStr, textStr1, textStr2);

								r.push('</td>');
							}

							r.push('</tr>');
						}

						r.push('</table>');

						////////////////////
						// Main Game Wins //
						////////////////////

						if (wins.filter(function(item) {return item.length != 0;} ).length != 0)
						{
							r.push('<p>' + getTranslationByName("mgWins", translations) + '</p>');

							ynIndex = keySymbs.indexOf('SM'); 

							if (wins[ynIndex].length > 0)
							{
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

								for (var smIndex = 0; smIndex < wins[ynIndex].length; smIndex++)
								{
									canvasIdStr   = 'cvsMGWin' + ynIndex.toString() + '_' + smIndex.toString();
									elementStr    = 'eleMGWin' + ynIndex.toString() + '_' + smIndex.toString();
									boxColourStr  = specialBoxColours[ynIndex];
									textStr1      = arrYourNums[wins[ynIndex][smIndex]].iValue.toString();
									textStr2      = convertedPrizeValues[getPrizeNameIndex(prizeNames, 'm' + arrYourNums[wins[ynIndex][smIndex]].sPrize)];
									mgTotal      += getPrizeInCents(textStr2);

									r.push('<tr class="tablebody">');
									r.push('<td>' + getTranslationByName("winMatches", translations) + '</td>');
									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, textStr1, '');

									r.push('</td>');
									r.push('<td>' + getTranslationByName("winToWin", translations) + ' ' + textStr2 + '</td>');
									r.push('</tr>');
								}

								r.push('</table>');
							}

							if (wins[keySymbs.indexOf('IW1')].length > 0)
							{
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

								for (var iwIndex = 0; iwIndex < 4; iwIndex++)
								{
									ynIndex = keySymbs.indexOf('IW' + (iwIndex+1).toString());

									if (wins[ynIndex].length > 0)
									{
										canvasIdStr   = 'cvsMGWin' + ynIndex.toString() + '_0';
										elementStr    = 'eleMGWin' + ynIndex.toString() + '_0';
										boxColourStr  = specialBoxColours[ynIndex];
										textStr1      = 'IW';
										textStr2      = convertedPrizeValues[getPrizeNameIndex(prizeNames, 'm' + arrYourNums[wins[ynIndex][0]].sPrize)];
										mgTotal      += getPrizeInCents(textStr2);

										r.push('<tr class="tablebody">');
										r.push('<td align="center">');

										showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, textStr1, '');

										r.push('</td>');
										r.push('<td colspan="3">' + getTranslationByName("winToWin", translations) + ' ' + textStr2 + '</td>');
										r.push('</tr>');

										for (var neighbourIndex = 1; neighbourIndex < wins[ynIndex].length; neighbourIndex++)
										{
											canvasIdStr   = 'cvsMGWin' + ynIndex.toString() + '_' + neighbourIndex.toString();
											elementStr    = 'eleMGWin' + ynIndex.toString() + '_' + neighbourIndex.toString();
											iwNeighbour   = wins[ynIndex][neighbourIndex];
											textStr1      = arrYourNums[iwNeighbour].iValue;
											textStr2      = convertedPrizeValues[getPrizeNameIndex(prizeNames, 'm' + arrYourNums[iwNeighbour].sPrize)];
											mgTotal      += getPrizeInCents(textStr2);

											r.push('<tr class="tablebody">');
											r.push('<td></td><td>' + getTranslationByName("winTriggers", translations) + '</td>');
											r.push('<td align="center">');

											showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, textStr1, '');

											r.push('</td>');
											r.push('<td>' + getTranslationByName("winToWin", translations) + ' ' + textStr2 + '</td>');
											r.push('</tr>');
										}
									}
								}

								r.push('</table>');
							}

							if (wins.filter(function(item,index) {return keySymbs[index][0] == 'P';} ).filter(function(item) {return item.length != 0;} ).length != 0)
							{
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
								r.push('<tr class="tablebody">');

								for (var pickerIndex = 0; pickerIndex < mgPickerSymbsQty; pickerIndex++)
								{
									ynIndex = keySymbs.indexOf('P' + (pickerIndex + 1).toString());

									if (wins[ynIndex].length > 0)
									{
										symbQty++;

										if (symbQty > 1) {r.push('<td>+</td>');}

										canvasIdStr   = 'cvsMGWin' + ynIndex.toString() + '_' + pickerIndex.toString();
										elementStr    = 'eleMGWin' + ynIndex.toString() + '_' + pickerIndex.toString();
										boxColourStr  = specialBoxColours[ynIndex];
										textColourStr = specialTextColours[ynIndex];
										textStr1      = 'P' + (pickerIndex + 1).toString();

										r.push('<td align="center">');

										showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, textColourStr, textStr1, '');

										r.push('</td>');
									}
								}

								r.push('<td> : ' + getTranslationByName("winCollected", translations) + ' ' + symbQty.toString() + ' / ' + mgPickerSymbsQty.toString() + '</td>');

								if (symbQty == mgPickerSymbsQty)
								{
									r.push('<td> : ' + getTranslationByName("winTriggers", translations) + ' ' + getTranslationByName("pickerBonus", translations) + '</td>');

									doPickerBonus = true;
								}

								r.push('</tr>');
								r.push('</table>');
							}

							ynIndex = keySymbs.indexOf('BS');

							if (wins[ynIndex].length > 0)
							{
								canvasIdStr   = 'cvsMGWin' + ynIndex.toString();
								elementStr    = 'eleMGWin' + ynIndex.toString();
								boxColourStr  = specialBoxColours[ynIndex];
								textColourStr = specialTextColours[ynIndex];
								textStr1      = 'BS';

								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
								r.push('<tr class="tablebody">');
								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, textColourStr, textStr1, '');

								r.push('</td>');
								r.push('<td> : ' + getTranslationByName("winCollected", translations) + ' ' + wins[ynIndex].length.toString() + ' / ' + mgMultiSymbsQty.toString() + '</td>');

								if (wins[ynIndex].length == mgMultiSymbsQty)
								{
									r.push('<td> : ' + getTranslationByName("winTriggers", translations) + ' ' + getTranslationByName("multiBonus", translations) + '</td>');

									doMultiBonus = true;
								}

								r.push('</tr>');
								r.push('</table>');
							}

							if (mgTotal != 0)
							{
								r.push('<p>' + getTranslationByName("mainGame", translations) + ' ' + getTranslationByName("mgTotalWin", translations) + ' = ' + getCentsInCurr(mgTotal) + '</p>');
							}
						}

						//////////////////
						// Picker Bonus //
						//////////////////

						if (doPickerBonus)
						{
							textStr1 = convertedPrizeValues[getPrizeNameIndex(prizeNames, 'p' + scenarioBonus1)];

							r.push('<p><br>' + getTranslationByName("pickerBonus", translations).toUpperCase() + '</p>');
							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablebody">');
							r.push('<td>' + getTranslationByName("mgWins", translations) + ' ' + textStr1 + '</td>');
							r.push('</tr>');
							r.push('</table>');
						}

						/////////////////
						// Multi Bonus //
						/////////////////

						if (doMultiBonus)
						{
							const bgSymbsQty  = 10;
							const bonusMultis = [1,2,3,5,10];
							const roundsQty   = 5;
							const chanceQty   = 3;

							var symbBonus        = [];
							var symbPrize        = '';
							var chanceMultiIndex = [0,0,0];
							var chanceStr        = '';
							var chanceSymb       = '';
							var chanceTarget     = '';
							var arrChances       = [];
							var multiStr         = '';
							var multiVal         = 0;
							var prizeVal         = 0;
							var roundStr         = '';
							var countText        = 0;
							var prizeStr         = '';
							var bgTotal          = 0;

							r.push('<p><br>' + getTranslationByName("multiBonus", translations).toUpperCase() + '</p>');

							///////////////////////
							// Bonus Symbols Key //
							///////////////////////

							r.push('<div style="float:left; margin-right:50px">');
							r.push('<p>' + getTranslationByName("titleBonusSymbolsKey", translations) + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
							r.push('<tr class="tablehead">');
							r.push('<td>' + getTranslationByName("keySymbol", translations) + '</td>');
							r.push('<td>' + getTranslationByName("keyDescription", translations) + '</td>');
							r.push('</tr>');

							for (var bgSymbIndex = 0; bgSymbIndex < bgSymbsQty; bgSymbIndex++) {symbBonus.push(String.fromCharCode('A'.charCodeAt() + bgSymbIndex));}

							for (var prizeIndex = 0; prizeIndex < symbBonus.length; prizeIndex++)
							{
								symbPrize    = symbBonus[prizeIndex];
								canvasIdStr  = 'cvsKeyBonus' + symbPrize;
								elementStr   = 'eleKeyBonus' + symbPrize;
								boxColourStr = bonusColours[prizeIndex];
								symbDesc     = 'symbB' + symbPrize;

								r.push('<tr class="tablebody">');
								r.push('<td align="center">');

								showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, symbPrize, '');

								r.push('</td>');
								r.push('<td style="padding-left:10px">' + getTranslationByName(symbDesc, translations) + '</td>');
								r.push('</tr>');
							}

							r.push('</table>');
							r.push('</div>');

							r.push('<p style="clear:both"><br>' + getTranslationByName("titleBonusRounds", translations).toUpperCase() + '</p>');

							r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');

							for (var roundIndex = 0; roundIndex < roundsQty; roundIndex++)
							{
								arrChances = scenarioBonus2[roundIndex].split(':');

								r.push('<tr class="tablebody">');

								////////////////
								// Round Info //
								////////////////

								roundStr = getTranslationByName("roundNum", translations) + ' ' + (roundIndex+1).toString() + ' ' + getTranslationByName("roundOf", translations) + ' ' + roundsQty.toString();

								r.push('<td valign="top">' + roundStr + '</td>');

								r.push('<td style="padding-left:50px; padding-right:50px; padding-bottom:25px">');
								r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
								r.push('<tr class="tablehead">');
								r.push('<td>&nbsp;</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusTarget", translations) + '</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusSymbol", translations) + '</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusMulti", translations) + '</td>');
								r.push('<td style="padding-left:20px; padding-right:20px">' + getTranslationByName("bonusWins", translations) + '</td>');
								r.push('</tr>');

								for (var chanceIndex = 0; chanceIndex < chanceQty; chanceIndex++)
								{
									r.push('<tr class="tablebody">');

									/////////////////
									// Chance Info //
									/////////////////

									chanceStr = getTranslationByName("chanceNum", translations) + ' ' + (chanceIndex+1).toString() + ' ' + getTranslationByName("chanceOf", translations) + ' ' + chanceQty.toString();

									r.push('<td>' + chanceStr + '</td>');

									////////////
									// Target //
									////////////

									chanceTarget = arrChances[chanceIndex][0];
									canvasIdStr  = 'cvsBonusTarget' + roundIndex.toString() + '_' + chanceIndex.toString();
									elementStr   = 'eleBonusTarget' + roundIndex.toString() + '_' + chanceIndex.toString();
									symbIndex    = symbBonus.indexOf(chanceTarget);
									boxColourStr = bonusColours[symbIndex];

									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, chanceTarget, '');

									r.push('</td>');

									////////////
									// Symbol //
									////////////

									chanceSymb   = arrChances[chanceIndex][1];
									canvasIdStr  = 'cvsBonusSymb' + roundIndex.toString() + '_' + chanceIndex.toString();
									elementStr   = 'eleBonusSymb' + roundIndex.toString() + '_' + chanceIndex.toString();
									symbIndex    = symbBonus.indexOf(chanceSymb);
									boxColourStr = bonusColours[symbIndex];

									r.push('<td align="center">');

									showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, chanceSymb, '');

									r.push('</td>');

									////////////////
									// Multiplier //
									////////////////

									multiVal = bonusMultis[chanceMultiIndex[chanceIndex]];
									multiStr = 'x' + multiVal.toString();

									r.push('<td align="center">' + multiStr + '</td>');

									//////////
									// Wins //
									//////////

									r.push('<td align="left">');

									if (chanceTarget == chanceSymb)
									{
										countText    = multiVal.toString() + ' x';
										canvasIdStr  = 'cvsBonusWin' + roundIndex.toString() + '_' + chanceIndex.toString();
										elementStr   = 'eleBonusWin' + roundIndex.toString() + '_' + chanceIndex.toString();
										symbIndex    = symbBonus.indexOf(chanceTarget);
										boxColourStr = bonusColours[symbIndex];
										prizeStr     = convertedPrizeValues[getPrizeNameIndex(prizeNames, 'b' + chanceTarget)];
										prizeVal     = getPrizeInCents(prizeStr) * multiVal;
										prizeStr     = getCentsInCurr(prizeVal);
										bgTotal     += prizeVal;

										r.push('<table border="0" cellpadding="2" cellspacing="1" class="gameDetailsTable">');
										r.push('<tr class="tablebody">');
										r.push('<td align="right">' + countText + '</td>');
										r.push('<td align="center">');

										showBox(canvasIdStr, elementStr, boxWidthKey, boxColourStr, colourBlack, chanceTarget, '');
										
										r.push('</td>');
										r.push('<td>= ' + prizeStr + '</td>');
										r.push('</tr>');
										r.push('</table>');

										chanceMultiIndex[chanceIndex]++;
									}

									r.push('</td>');
									r.push('</tr>');
								}

								r.push('</table>');
								r.push('</td>');
								r.push('</tr>');
							}

							r.push('</table>');

							r.push('<p>' + getTranslationByName("multiBonus", translations) + ' ' + getTranslationByName("mgTotalWin", translations) + ' = ' + getCentsInCurr(bgTotal) + '</p>');
						}

						r.push('<p>&nbsp;</p>');

						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						// DEBUG OUTPUT TABLE
						////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
						if (debugFlag)
						{
							//////////////////////////////////////
							// DEBUG TABLE
							//////////////////////////////////////
							r.push('<table border="0" cellpadding="2" cellspacing="1" width="100%" class="gameDetailsTable" style="table-layout:fixed">');
							for (var idx = 0; idx < debugFeed.length; idx++)
 							{
								if (debugFeed[idx] == "")
									continue;
								r.push('<tr>');
 								r.push('<td class="tablebody">');
								r.push(debugFeed[idx]);
 								r.push('</td>');
	 							r.push('</tr>');
							}
							r.push('</table>');
						}

						return r.join('');
					}

					// Input: A list of Price Points and the available Prize Structures for the game as well as the wagered price point
					// Output: A string of the specific prize structure for the wagered price point
					function retrievePrizeTable(pricePoints, prizeStructures, wageredPricePoint)
					{
						var pricePointList = pricePoints.split(",");
						var prizeStructStrings = prizeStructures.split("|");
						
						for (var i = 0; i < pricePoints.length; ++i)
						{
							if (wageredPricePoint == pricePointList[i])
							{
								return prizeStructStrings[i];
							}
						}
						
						return "";
					}

					// Input: Json document string containing 'scenario' at root level.
					// Output: Scenario value.
					function getScenario(jsonContext)
					{
						// Parse json and retrieve scenario string.
						var jsObj = JSON.parse(jsonContext);
						var scenario = jsObj.scenario;

						// Trim null from scenario string.
						scenario = scenario.replace(/\0/g, '');

						return scenario;
					}
					
					// Input: Json document string containing 'amount' at root level.
					// Output: Price Point value.
					function getPricePoint(jsonContext)
					{
						// Parse json and retrieve price point amount
						var jsObj = JSON.parse(jsonContext);
						var pricePoint = jsObj.amount;

						return pricePoint;
					}

					// Input: "A,B,C,D,..." and "A"
					// Output: index number
					function getPrizeNameIndex(prizeNames, currPrize)
					{
						for(var i = 0; i < prizeNames.length; i++)
						{
							if (prizeNames[i] == currPrize)
							{
								return i;
							}
						}
					}

					////////////////////////////////////////////////////////////////////////////////////////
					function registerDebugText(debugText)
					{
						debugFeed.push(debugText);
					}
					/////////////////////////////////////////////////////////////////////////////////////////

					function getTranslationByName(keyName, translationNodeSet)
					{
						var index = 1;
						while(index < translationNodeSet.item(0).getChildNodes().getLength())
						{
							var childNode = translationNodeSet.item(0).getChildNodes().item(index);
							
							if (childNode.name == "phrase" && childNode.getAttribute("key") == keyName)
							{
								//registerDebugText("Child Node: " + childNode.name);
								return childNode.getAttribute("value");
							}
							
							index += 1;
						}
					}

					// Grab Wager Type
					// @param jsonContext String JSON results to parse and display.
					// @param translation Set of Translations for the game.
					function getType(jsonContext, translations)
					{
						// Parse json and retrieve wagerType string.
						var jsObj = JSON.parse(jsonContext);
						var wagerType = jsObj.wagerType;

						return getTranslationByName(wagerType, translations);
					}
					]]>
				</lxslt:script>
			</lxslt:component>

			<x:template match="root" mode="last">
				<table border="0" cellpadding="1" cellspacing="1" width="100%" class="gameDetailsTable">
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWager']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/WagerOutcome[@name='Game.Total']/@amount" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
					<tr>
						<td valign="top" class="subheader">
							<x:value-of select="//translation/phrase[@key='totalWins']/@value" />
							<x:value-of select="': '" />
							<x:call-template name="Utils.ApplyConversionByLocale">
								<x:with-param name="multi" select="/output/denom/percredit" />
								<x:with-param name="value" select="//ResultData/PrizeOutcome[@name='Game.Total']/@totalPay" />
								<x:with-param name="code" select="/output/denom/currencycode" />
								<x:with-param name="locale" select="//translation/@language" />
							</x:call-template>
						</td>
					</tr>
				</table>
			</x:template>

			<!-- TEMPLATE Match: digested/game -->
			<x:template match="//Outcome">
				<x:if test="OutcomeDetail/Stage = 'Scenario'">
					<x:call-template name="Scenario.Detail" />
				</x:if>
			</x:template>

			<!-- TEMPLATE Name: Scenario.Detail (base game) -->
			<x:template name="Scenario.Detail">
				<x:variable name="odeResponseJson" select="string(//ResultData/JSONOutcome[@name='ODEResponse']/text())" />
				<x:variable name="translations" select="lxslt:nodeset(//translation)" />
				<x:variable name="wageredPricePoint" select="string(//ResultData/WagerOutcome[@name='Game.Total']/@amount)" />
				<x:variable name="prizeTable" select="lxslt:nodeset(//lottery)" />

				<table border="0" cellpadding="0" cellspacing="0" width="100%" class="gameDetailsTable">
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='wagerType']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="my-ext:getType($odeResponseJson, $translations)" disable-output-escaping="yes" />
						</td>
					</tr>
					<tr>
						<td class="tablebold" background="">
							<x:value-of select="//translation/phrase[@key='transactionId']/@value" />
							<x:value-of select="': '" />
							<x:value-of select="OutcomeDetail/RngTxnId" />
						</td>
					</tr>
				</table>
				<br />			
				
				<x:variable name="convertedPrizeValues">
					<x:apply-templates select="//lottery/prizetable/prize" mode="PrizeValue"/>
				</x:variable>

				<x:variable name="prizeNames">
					<x:apply-templates select="//lottery/prizetable/description" mode="PrizeDescriptions"/>
				</x:variable>


				<x:value-of select="my-ext:formatJson($odeResponseJson, $translations, $prizeTable, string($convertedPrizeValues), string($prizeNames))" disable-output-escaping="yes" />
			</x:template>

			<x:template match="prize" mode="PrizeValue">
					<x:text>|</x:text>
					<x:call-template name="Utils.ApplyConversionByLocale">
						<x:with-param name="multi" select="/output/denom/percredit" />
					<x:with-param name="value" select="text()" />
						<x:with-param name="code" select="/output/denom/currencycode" />
						<x:with-param name="locale" select="//translation/@language" />
					</x:call-template>
			</x:template>
			<x:template match="description" mode="PrizeDescriptions">
				<x:text>,</x:text>
				<x:value-of select="text()" />
			</x:template>

			<x:template match="text()" />
		</x:stylesheet>
	</xsl:template>

	<xsl:template name="TemplatesForResultXSL">
		<x:template match="@aClickCount">
			<clickcount>
				<x:value-of select="." />
			</clickcount>
		</x:template>
		<x:template match="*|@*|text()">
			<x:apply-templates />
		</x:template>
	</xsl:template>
</xsl:stylesheet>
