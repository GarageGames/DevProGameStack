/*
* Copyright 2015 GarageGames LLC
*/

package ui {
	import flash.display.Sprite;
	import flash.text.TextField;
	
	import assets.Resources;
	
	import scratch.ScratchCostume;
	import scratch.ScratchObj;
	import scratch.ScratchSprite;
	
	import translation.Translator;
	
	import ui.media.MediaInfo;
	import ui.media.MediaPane;
	
	import uiwidgets.DialogBox;
	import uiwidgets.ScrollFrame;
	import uiwidgets.ScrollFrameContents;
	
	public class TemplateObjPane extends ScrollFrameContents {
		
		protected var lastSelected:int = -1;
		public var chosenObject:ScratchObj = null;
		
		public function TemplateObjPane():void {
			refresh();
		}
		
		public function refresh():void {
			if (Designer.dapp.viewedObj() == null) return;
			replaceContents(templateItems());
			updateSelection();
		}
		
		private function replaceContents(newItems:Array):void {
			while (numChildren > 0) removeChildAt(0);
			var nextY:int = 3;
			var nextX:int = 0;
			var columnCount:int = 0;
			var n:int = 1;
			for each (var item:Sprite in newItems) {
				//var numLabel:TextField = Resources.makeLabel('' + n++, CSS.thumbnailExtraInfoFormat);
				//numLabel.x = 9;
				//numLabel.y = nextY + 1;
				item.x = nextX + 7;
				item.y = nextY;
				addChild(item);
				//addChild(numLabel);
				
				columnCount++;
				if(columnCount < 4) {
					nextX += item.width + 3;
				}
				else {
					columnCount = 0;
					nextX = 0;
					nextY += item.height + 3;
				}
			}
			updateSize();
			//lastCostume = null;
			x = y = 0; // reset scroll offset
		}
		
		private function templateItems():Array {
			var result:Array = [];
			for each (var c:ScratchSprite in Designer.dapp.stagePane.templateSprites()) {
				var mi:MediaInfo = Scratch.app.createMediaInfo(c, c);
				mi.allowGrabbing = false;
				mi.removeDeleteButton();
				mi.clickCallback = itemClicked;
				result.push(mi);
			}
			return result;
		}
		
		// Returns true if the costume changed
		private function updateSelection():Boolean {
			if(lastSelected < 0) {
				lastSelected = 0;
			}
			
			// Choose a new selected template
			for (var i:int = 0 ; i < numChildren ; i++) {
				var ci:MediaInfo = getChildAt(i) as MediaInfo;
				if (ci != null) {
					if (i == lastSelected) {
						ci.highlight();
						//scrollToItem(ci);
						chosenObject = ci.owner;
					} else {
						ci.unhighlight();
					}
				}
			}
				
			
			//var viewedObj:ScratchObj = app.viewedObj();
			//if ((viewedObj == null) || isSound) return false;
			//var current:ScratchCostume = viewedObj.currentCostume();
			//if (current == lastCostume) return false;
			//var oldCostume:ScratchCostume = lastCostume;
			//for (var i:int = 0 ; i < numChildren ; i++) {
			//	var ci:MediaInfo = getChildAt(i) as MediaInfo;
			//	if (ci != null) {
			//		if (ci.mycostume == current) {
			//			ci.highlight();
			//			scrollToItem(ci);
			//		} else {
			//			ci.unhighlight();
			//		}
			//	}
			//}
			//lastCostume = current;
			//return (oldCostume != null);
			
			return true;
		}
		
		public function itemClicked(item:MediaInfo):void {
			// Find the item selected
			var selectedIndex:int = -1;
			for (var i:int = 0 ; i < numChildren ; i++) {
				var ci:MediaInfo = getChildAt(i) as MediaInfo;
				if (ci != null) {
					if (ci == item) {
						selectedIndex = i;
						break;
					}
				}
			}
			
			if(selectedIndex >= 0 && selectedIndex != lastSelected) {
				lastSelected = selectedIndex;
				updateSelection();
			}
		}
	}

}