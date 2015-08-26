/*
 * Copyright 2015 GarageGames LLC
 */

package ui {
	import flash.display.Sprite;
	import flash.text.TextField;
	
	import assets.Resources;
	
	import translation.Translator;
	
	import ui.media.MediaPane;
	
	import uiwidgets.DialogBox;
	import uiwidgets.ScrollFrame;
	import uiwidgets.ScrollFrameContents;

public class TemplateObjDialog extends DialogBox {
	
	private var templateList:TemplateObjPane;
	private var scroller:ScrollFrame;
	
	private var templateChosenFunc:Function;
	
	public static function strings():Array {
		return ['Choose Template Sprite', 'OK', 'Cancel'];
	}

	public function TemplateObjDialog(templateChosenFunc:Function) {
		super();
		this.templateChosenFunc = templateChosenFunc;
		
		addTitle(Translator.map('Choose Template Sprite'));

		templateList = new TemplateObjPane();
		scroller = new ScrollFrame();
		scroller.allowHorizontalScrollbar = false;
		scroller.setContents(templateList);
		scroller.setWidthHeight(380, 400);
		addWidget(scroller);
		
		addButton('OK', okButtonClicked);
		addButton('Cancel', cancelButtonClicked);
		
		showOnStage(Scratch.app.stage);
	}
	
	protected function okButtonClicked():void {
		if(templateList.chosenObject != null) {
			templateChosenFunc(templateList.chosenObject);
		}
	}
	
	protected function cancelButtonClicked():void {
		
	}
}

}