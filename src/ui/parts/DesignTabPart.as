/*
* Scratch Project Editor and Player
* Copyright (C) 2014 Massachusetts Institute of Technology
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public License
* as published by the Free Software Foundation; either version 2
* of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program; if not, write to the Free Software
* Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

// ScriptsPart.as
// John Maloney, November 2011
//
// This part holds the palette and scripts pane for the current sprite (or stage).

package ui.parts {
	import flash.display.Bitmap;
	import flash.display.DisplayObject;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.getTimer;
	
	import blocks.Block;
	
	import scratch.ScratchComment;
	import scratch.ScratchObj;
	import scratch.ScratchRuntime;
	import scratch.ScratchSprite;
	
	import ui.BlockPalette;
	import ui.PaletteSelector;
	
	import uiwidgets.IndicatorLight;
	import uiwidgets.ScriptsPane;
	import uiwidgets.ScrollFrame;
	import uiwidgets.ZoomWidget;
	
	import watchers.ListWatcher;
	import watchers.Watcher;
	
	public class DesignTabPart extends UIPart {
		
		public var dapp:Designer;

		private var shape:Shape;
		private var selector:PaletteSelector;
		private var spriteWatermark:Bitmap;
		private var paletteFrame:ScrollFrame;
		private var scriptsPane:ScriptsPane;
		private var scriptsFrame:ScrollFrame;
		private var zoomWidget:ZoomWidget;
		
		private const readoutLabelFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor, true);
		private const readoutFormat:TextFormat = new TextFormat(CSS.font, 12, CSS.textColor);
		
		private var xyDisplay:Sprite;
		private var xLabel:TextField;
		private var yLabel:TextField;
		private var xReadout:TextField;
		private var yReadout:TextField;
		private var lastX:int = -10000000; // impossible value to force initial update
		private var lastY:int = -10000000; // impossible value to force initial update
		
		private var designLabelDisplay:Sprite;
		private var designLabel:TextField;

		public function DesignTabPart(app:Designer) {
			this.app = app as Scratch;
			this.dapp = app;
			
			addChild(shape = new Shape());
			//addChild(spriteWatermark = new Bitmap());
			//addXYDisplay();
			//addChild(selector = new PaletteSelector(app));
			
			//var palette:BlockPalette = new BlockPalette();
			//palette.color = CSS.tabColor;
			//paletteFrame = new ScrollFrame();
			//paletteFrame.allowHorizontalScrollbar = false;
			//paletteFrame.setContents(palette);
			//addChild(paletteFrame);
			
			addDesignLabel();
			
			scriptsPane = new ScriptsPane(app);
			scriptsFrame = new ScrollFrame();
			scriptsFrame.setContents(scriptsPane);
			addChild(scriptsFrame);
			
			//app.palette = palette;
			//app.scriptsPane = scriptsPane;
			
			addChild(zoomWidget = new ZoomWidget(scriptsPane));
		}
		
		public function step():void {
			// Update the mouse readouts. Do nothing if they are up-to-date (to minimize CPU load).
			var target:ScratchObj = app.viewedObj();
			// Designer: The target object could be null when we first start with a project template rather than an empty scene
			if(target == null) {
				return;
			}
			//if (target.isStage) {
				//if (xyDisplay.visible) xyDisplay.visible = false;
			//} else {
			//	if (!xyDisplay.visible) xyDisplay.visible = true;
			//	
			//	var spr:ScratchSprite = target as ScratchSprite;
			//	if (!spr) return;
			//	if (spr.scratchX != lastX) {
			//		lastX = spr.scratchX;
			//		xReadout.text = String(lastX);
			//	}
			//	if (spr.scratchY != lastY) {
			//		lastY = spr.scratchY;
			//		yReadout.text = String(lastY);
			//	}
			//}
			//updateExtensionIndicators();
		}
		
		public function watcherStep(runtime:ScratchRuntime):void {
			for (var i:int = 0; i < scriptsPane.numChildren; i++) {
				var c:DisplayObject = scriptsPane.getChildAt(i);
				if (c.visible == true) {
					if (c is Watcher) Watcher(c).step(runtime);
					if (c is ListWatcher) ListWatcher(c).step();
				}
			}
		}
		
		private var lastUpdateTime:uint;
		
		private function updateExtensionIndicators():void {
			if ((getTimer() - lastUpdateTime) < 500) return;
			for (var i:int = 0; i < app.palette.numChildren; i++) {
				var indicator:IndicatorLight = app.palette.getChildAt(i) as IndicatorLight;
				if (indicator) app.extensionManager.updateIndicator(indicator, indicator.target);
			}		
			lastUpdateTime = getTimer();
		}
		
		public function setWidthHeight(w:int, h:int):void {
			this.w = w;
			this.h = h;
			fixlayout();
			redraw();
		}
		
		private function fixlayout():void {
			scriptsFrame.x = 5;
			scriptsFrame.y = 6;
			scriptsFrame.setWidthHeight(w - scriptsFrame.x - 5, h - scriptsFrame.y - 5);
			
			zoomWidget.x = w - zoomWidget.width - 15;
			zoomWidget.y = h - zoomWidget.height - 15;

			designLabelDisplay.x = w - 60;
			designLabelDisplay.y = scriptsFrame.y + 10;
		}
		
		private function redraw():void {
			var scriptsW:int = scriptsFrame.visibleW();
			var scriptsH:int = scriptsFrame.visibleH();
			
			var g:Graphics = shape.graphics;
			g.clear();
			g.lineStyle(1, CSS.borderColor, 1, true);
			g.beginFill(CSS.tabColor);
			g.drawRect(0, 0, w, h);
			g.endFill();
			
			var darkerBorder:int = CSS.borderColor - 0x141414;
			g.lineStyle(1, darkerBorder, 1, true);
			g.drawRect(scriptsFrame.x - 1, scriptsFrame.y - 1, scriptsW + 1, scriptsH + 1);
		}
		
		private function addDesignLabel():void {
			designLabelDisplay = new Sprite();
			designLabelDisplay.addChild(designLabel = makeLabel('Design', readoutLabelFormat, 0, 0));
			addChild(designLabelDisplay);
		}
		
		public function addWatcher(w:Watcher):void {
			w.designTabWatcher = true;
			setInitialPosition(w);
			scriptsPane.addChild(w);
		}
		
		public function removeWatcher(w:Watcher):void {
			scriptsPane.removeChild(w);
		}
		
		public function addListWatcher(lw:ListWatcher):void {
			lw.designTabListWatcher = true;
			setInitialPosition(lw);
			scriptsPane.addChild(lw);
		}

		public function removeListWatcher(lw:ListWatcher):void {
			scriptsPane.removeChild(lw);
		}
		
		public function clearAllWatchers():void {
			var wList:Array = watchers();
			for each (var w:DisplayObject in wList) {
				if(w is ListWatcher) {
					ListWatcher(w).clearOriginalConnection();
				}
				scriptsPane.removeChild(w);
			}
		}
		
		public function watchers():Array {
			// Return an array of all variable and lists on the stage, visible or not.
			var result:Array = [];
			for (var i:int = 0; i < scriptsPane.numChildren; i++) {
				var o:* = scriptsPane.getChildAt(i);
				if ((o is Watcher) || (o is ListWatcher)) result.push(o);
			}
			return result;
		}
		
		private function setInitialPosition(watcher:DisplayObject):void {
			var scriptsW:int = scriptsFrame.visibleW();
			var scriptsH:int = scriptsFrame.visibleH();
			
			var wList:Array = watchers();
			var w:int = watcher.width;
			var h:int = watcher.height;
			var x:int = 7;
			
			while (x < scriptsW) {
				var maxX:int = 0;
				var y:int = 7;
				while (y < scriptsH) {
					var otherWatcher:DisplayObject = watcherIntersecting(wList, new Rectangle(x, y, w, h));
					if (!otherWatcher) {
						watcher.x = x;
						watcher.y = y;
						return;
					}
					y = otherWatcher.y + otherWatcher.height + 5;
					maxX = otherWatcher.x + otherWatcher.width;
				}
				x = maxX + 5;
			}
			// Couldn't find an unused place, so pick a random spot
			watcher.x = 5 + Math.floor(400 * Math.random());
			watcher.y = 5 + Math.floor(320 * Math.random());
		}
		
		private function watcherIntersecting(watchers:Array, r:Rectangle):DisplayObject {
			for each (var w:DisplayObject in watchers) {
				if (r.intersects(w.getBounds(scriptsPane))) return w;
			}
			return null;
		}
		
		public function handleDrop(obj:*):Boolean {
			var localP:Point = globalToLocal(new Point(obj.x, obj.y));
			
			var w:Watcher = obj as Watcher;
			var lw:ListWatcher = obj as ListWatcher;
			if (!w && !lw) return false;
			
			if(w) {
				w.designTabWatcher = true;
				w.x = Math.max(5, localP.x);
				w.y = Math.max(5, localP.y);
				w.scaleX = w.scaleY = 1;
				
				scriptsPane.addChild(w);
			}

			// Only accept a ListWatcher that is already on the Design tab (just moving it)
			if(lw && lw.designTabListWatcher) {
				lw.x = Math.max(5, localP.x);
				lw.y = Math.max(5, localP.y);
				lw.scaleX = lw.scaleY = 1;
				scriptsPane.addChild(lw);
			}
			
			fixlayout();
			redraw();
			scriptsPane.updateSize();
			
			return true;
		}
	}
}
