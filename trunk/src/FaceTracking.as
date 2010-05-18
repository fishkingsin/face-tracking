package {

	import flash.display.*;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.utils.ByteArray;
	import flash.geom.*;
	import flash.geom.Rectangle;
	import flash.geom.ColorTransform;
	import flash.filters.*;
	import flash.display.Shape;
	import fl.controls.*;

	public class FaceTracking extends MovieClip {
		
		private var video1	: Video;		
		private var webcam	: Camera;	


		private var sprite1			: Sprite;
		private var sprite2			: Sprite;
		private var sprite3			: Sprite;
		private var sprite4			: Sprite;
		private var sprite5			: Sprite;
		private var sprite6			: Sprite;

		//   A BitmapData is Flash's version of a JPG image in memory.
		private var bmBase			: BitmapData;
		private var bmBlur			: BitmapData;
		private var bmTarget		: BitmapData;
		private var bmPrev			: BitmapData;
		private var bmFiltered		: BitmapData;
		private var bmFinal			: BitmapData;
		private var bmFace			: BitmapData;
		private var bmEyes			: BitmapData;
		private var bmContrast		: BitmapData;
		private var bmEdges			: BitmapData;
		private var bitmap4			: BitmapData;
		private var bitmap5			: BitmapData;
		private var bitmap6			: BitmapData;
		
		//	Fun, Editable Properties
		private var VIDEO_WIDTH 			: Number = 320;				//Set 100 to 1000 to set width of screen
		private var VIDEO_HEIGHT 			: Number = 240;				//Set 100 to 1000 to set height of screen
		private var WEB_CAMERA_WIDTH 		: Number = VIDEO_WIDTH/1;	//Smaller than video runs faster
		private var WEB_CAMERA_HEIGHT 		: Number = VIDEO_HEIGHT/1;	//Smaller than video runs faster
		private var VIDEO_FRAME_RATE 		: Number = 60;				//Set 5 to 30.  Higher values = smoother video
		
		

		private var eyes					: Object = new Object();
		private var faceRect				: Rectangle;
		
		
		private var DEFAULT_POINT			: Point = new Point(0,0);
		private var debugCount 				: Number = 0;
		private var fps		 				: uint = 0;
		private var fpsCount 				: uint = 0;
		private var fpsTimer 				: uint = 0;
		
		private static var MAX_CHROMATICITY	: uint = 60;
		
		
		
		
		public function FaceTracking() {
			
			eyes.models = [];
			eyes.hits = [];
			eyes.pairs = [];

			prepareWebCam();
			
			addEventListener(Event.ENTER_FRAME, drawFrame);
		}
		
		
		private function prepareWebCam() : void {
			webcam = Camera.getCamera();
			webcam.setMode(WEB_CAMERA_WIDTH, WEB_CAMERA_HEIGHT, VIDEO_FRAME_RATE);
			
			// The original video feed
			video1 = new Video(VIDEO_WIDTH, VIDEO_HEIGHT);
			video1.attachCamera(webcam);
			sprite1 = new Sprite();
			//sprite1.addChild(video1);

			// 
			sprite2 = new Sprite();
			sprite2.x = VIDEO_WIDTH*1;
			sprite2.y = VIDEO_HEIGHT*0;

			// 
			sprite3 = new Sprite();
			sprite3.x = VIDEO_WIDTH*2;
			sprite3.y = VIDEO_HEIGHT*0;

			// 
			sprite4 = new Sprite();
			sprite4.x = VIDEO_WIDTH*0;
			sprite4.y = VIDEO_HEIGHT*1;

			// 
			sprite5 = new Sprite();
			sprite5.x = VIDEO_WIDTH*1;
			sprite5.y = VIDEO_HEIGHT*1;

			// 
			sprite6 = new Sprite();
			sprite6.x = VIDEO_WIDTH*2;
			sprite6.y = VIDEO_HEIGHT*1;


			addChild(sprite1);
			addChild(sprite2);
			addChild(sprite3);
			addChild(sprite4);
			addChild(sprite5);
			addChild(sprite6);
			
			//   A BitmapData is Flash's version of a JPG image in memory.
            bmBase = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
            bmPrev = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
            bmFiltered = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
            bmFace = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
            bmEyes = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
            bmEdges = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
            bitmap6 = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
		}
		
		private function drawFrame(aEvent : Event) : void {
			var startTime:Date = new Date();
			var rect:Rectangle = new Rectangle(0, 0, VIDEO_WIDTH, VIDEO_HEIGHT);
			var blur:BlurFilter = new BlurFilter(2,2,2);			
			var GAUSSIAN_3BY3:ConvolutionFilter = new ConvolutionFilter(3,3,[ 1,2,1,
 																		 	  2,4,2,
																			  1,2,1], 16);
			
			MAX_CHROMATICITY = chromaticity_mc.value;
			
			//	Copy the latest still-frame of the webcam video into the BitmapData object for detection
			bmBase.draw(video1);
			
			
			// Filter and process the base image to detect the face area using the skin color
			
			var scaleAmount:Number = 2;
			var scale:Number = 1/scaleAmount;
			bmFiltered = new BitmapData(VIDEO_WIDTH*scale, VIDEO_HEIGHT*scale);
			var m:Matrix = new Matrix();
		    m.scale(scale, scale);
			bmFiltered.draw(bmBase, m);
			//bmEyes = bmFiltered.clone();
			//bmFiltered.applyFilter(bmFiltered, rect, new Point(0,0), GAUSSIAN_3BY3);
			bmFiltered.applyFilter(bmFiltered, rect, new Point(0,0), blur);
			filterSkin(bmFiltered);
			//bmFiltered.threshold(bmFiltered, rect, new Point(0,0), ">", 0x66, 0xFFFFFFFF, 0xFF);
			
			// Find the approximate face position and it's rectangle
			var faceRectSmall:Rectangle = findFacePositions(bmFiltered);
			faceRect = faceRectSmall.clone();
			faceRect.x *= scaleAmount;
			faceRect.y *= scaleAmount;
			faceRect.width *= scaleAmount;
			faceRect.height *= scaleAmount;

			// Make the pic bigger
			m.identity();
		    m.scale(scaleAmount, scaleAmount);
			bmFace.draw(bmFiltered, m);			
			
			// Create a green bordered face rectangle helper shape
			var faceBorders:Shape = new Shape();
			faceBorders.graphics.lineStyle(1, 0x0000FF);
			faceBorders.graphics.drawRect(faceRect.x, faceRect.y, faceRect.width, faceRect.height);
			
			// Draw the face area helper image
			drawToSprite(sprite3, bmFace);
			
			
			// Draw the base image with the detected areas
			bmFinal = bmBase;
			bmFinal.draw(faceBorders);			
			drawToSprite(sprite4, bmFinal);
						
			// Preprocess the detected face area for eye detection
			var eyesRectSmall:Rectangle = new Rectangle(faceRectSmall.x, faceRectSmall.y+faceRectSmall.height*0.1, faceRectSmall.width, faceRectSmall.height*0.5);
			var eyesRect:Rectangle = new Rectangle(faceRect.x, faceRect.y+faceRect.height*0.1, faceRect.width, faceRect.height*0.5);
			//bmEyes.applyFilter(bmEyes, faceRectSmall, faceRectSmall.topLeft, GAUSSIAN_3BY3);
			bmEyes = bmFiltered.clone();
			//preprocessEyesArea(bmEyes, bmEyes, eyesRectSmall);
			
			// Find the potential eye shapes. These are round shapes. Add these eyes into the eye models list.
			eyes.hits = findEyes(bmEyes, eyesRectSmall);
			//eyes.models.sort(sortByRelevance);
			drawToSprite(sprite1, bmEyes);
			
			// Create a green bordered face rectangle helper shape
			var eyesBorders:Shape = new Shape();
			eyesBorders.graphics.lineStyle(1, 0x00FF00);
			eyesBorders.graphics.drawRect(eyesRect.x, eyesRect.y, eyesRect.width, eyesRect.height);
			bmFinal.draw(eyesBorders);
			
			// Find an eye pair from the list of eye hits
			findEyePairs(eyesRectSmall);
			drawEyePairs(bmEyes);
			drawEyePairs(bmFinal, scaleAmount);

			/*
			// Find eye pairs from the list of eye models
			findEyePairs();
			eyes.pairs.sort(sortByRelevance);

			// Draw 2 of the most promising eye models
			drawEyePairs(bmEyes);
			drawEyePairs(bmFinal, 2);
			drawEyeModels(bmEyes);
			//drawEyeModels(bmFinal, 2);
			
			// Decrement and remove non relevant eye models
			maintainEyeModels();
			*/

			debug_txt.text = 'Hits:' + eyes.hits.length + ' Models:' + eyes.models.length + ' Pairs:' + eyes.pairs.length;
			
			// Calculate the FPS and frame time 
			var now:uint = new Date().getTime();
			var frameTime:uint  = now - startTime.getTime();
			frameTime_txt.text = 'Frame time: ' +frameTime+ ' ms, FPS: ' + fps;
			if (now - fpsTimer > 1000) {
				fpsTimer = now;
				fps = fpsCount;
				fpsCount = 0;
			} 
			fpsCount++;
		}

		// Finds all potential face positions
		private function findFacePositions(bmd) : Rectangle {
			var w:uint = bmd.width;
			var h:uint = bmd.height;
			var x:uint;
			var y:uint;
			var c:uint;
			var target:Object = new Object();
			target.x = 0 as uint;
			target.y = 0 as uint;
			target.w = 0 as uint;
			var currentWidth:int = 0;
			var findColor:uint = 0xFF000010;
			var faces:Array = [];
			var rect:Rectangle;
			var bestFace:Rectangle = new Rectangle();
			
			// First find the widest black line
			for (y=0; y<h; y+=10){
				for (x=0; x<w; x+=10){
					c = bmd.getPixel(x, y);
					if (c == 0) {
						// Found a potential face aread
						findColor += 5;
						bmd.floodFill(x, y, findColor);
						rect = bmd.getColorBoundsRect(0xFF0000FF, findColor, true);
						if (rect.width > 20 && rect.height*1.3 > rect.width){
							// Found one face
							//faces.push(rect);
							if (rect.width > bestFace.width) bestFace = rect;
						}
					}
				}
			}

			// Finally we can make a rectangle out of the data
			var found:Shape = new Shape();
			found.graphics.lineStyle(1, 0x0000FF);
			found.graphics.drawRect(bestFace.x, bestFace.y, bestFace.width, bestFace.height);
			bmd.draw(found);
			return bestFace;
		}		
		
		function filterSkin(bmd):void {
			// Get pixels and loop through them
			var rectSmall:Rectangle = new Rectangle(0, 0, bmd.width, bmd.height);
			var pixels:ByteArray = bmd.getPixels(rectSmall);
			pixels.position = 0;
			var c:uint;
			var r:uint;
			var g:uint;
			var b:uint;
			var rn:uint;
			var gn:uint;
			var bn:uint;
			var cr:Number;
			var cg:Number;
			var cb:Number;
			var total:uint;
			var hue:int;
			//var cr:uint;
			var max:uint;
			var min:uint;
			var sat:uint;
			var chroma:uint;
			while (pixels.bytesAvailable > 0) {
				c = pixels.readUnsignedInt();
				r = c >> 16 & 0xFF;
				g = c >> 8 & 0xFF;
				b = c & 0xFF;
				max = Math.max(r, g, b);
				min = Math.min(r, g, b);
				chroma = max-min;
				
				// Filter with chromatisity
				if (skin_chroma_mc.selected) {
					if (chroma < MAX_CHROMATICITY) {
						// This is not a skin pixel
						pixels.position -= 4;
						pixels.writeUnsignedInt(0xFFFFFFFF);
						continue;
					}
				}

				// Filter with saturation
				if (skin_sat_mc.selected) {
					sat = (chroma << 8) /max;
					if (sat < 58/* || sat > 174*/) {
						// This is not a skin pixel
						pixels.position -= 4;
						pixels.writeUnsignedInt(0xFFFFFFFF);
						continue;
					}
				}

				// Normalize colors
				total = r+g+b;
				rn = (r << 8) / total;
				gn = (g << 8) / total;
				bn = (b << 8) / total;
				
				if (skin_cr_mc.selected) {
					// Filter with Cr color component 
					cr = RGBtoCr(rn, gn, bn);
					if (cr < 133 || cr > 173) {
						// Not a skin pixel
						pixels.position -= 4;
						pixels.writeUnsignedInt(0xFFFFFFFF);
						continue;
					}
				}
				
				
				if (skin_hue_mc.selected) {					
					// Filter with HUE color component
					hue = getHue(r, g, b, max, min, chroma);
					if (hue <= 0 || hue > 50) {
						// Not a skin pixel
						pixels.position -= 4;
						pixels.writeUnsignedInt(0xFFFFFFFF);
						continue;
					}
				}
				
				if (skin_rgb_mc.selected) {
					if (rn < 40 || rn > 128 || bn < 38 || bn > 77) {
						// This is not a skin pixel
						pixels.position -= 4;
						pixels.writeUnsignedInt(0xFFFFFFFF);
						continue;
					}					
				}
								
				pixels.position -= 4;
				pixels.writeUnsignedInt(0xFF000000);
			}
			pixels.position = 0;
			bmd.setPixels(rectSmall, pixels);			
		}
		
		function sortByRelevance(a, b):Number {
			if (a.relevance > b.relevance) {
				return -1;
			} else if (a.relevance < b.relevance) {
				return 1;
			} else  {
				return 0;
			}
		}
		
		private function drawEyePairs(bmd:BitmapData, scale:uint = 1) : void {
			for (var i in eyes.pairs){
				var pair:Object = eyes.pairs[i];

				var rect:Shape = new Shape();    
				rect.graphics.lineStyle(2, 0xFF0000);
				rect.graphics.drawRect(pair.e1.x*scale, pair.e1.y*scale, pair.e1.width*scale, pair.e1.height*scale);
				bmd.draw(rect);
				
				rect.graphics.drawRect(pair.e2.x*scale, pair.e2.y*scale, pair.e2.width*scale, pair.e2.height*scale);
				bmd.draw(rect);
			}
		}
		// Draw drawCount eye models. Sorted by relevance.
		private function drawEyeModels(bmd:BitmapData, drawCount:uint = 100) : void {
			for (var i in eyes.models){
				var m:Object = eyes.models[i];
				if (m.relevance < 10) continue;

				var rect:Shape = new Shape();
				//var lineWidth = m.paired > 0 ? 3 : 1;
				var lineWidth = 1;
				rect.graphics.lineStyle(lineWidth, 0x00FF00);
				rect.graphics.drawRect(m.p.x-m.radius, m.p.y-m.radius, m.w, m.w);
				bmd.draw(rect);
				if (--drawCount == 0) return;
			}
		}
				
		// Find eye pairs from the eye hits based on relative location and size
		private function findEyePairs(eyesRect) : void {
			eyes.pairs =[];

			// Loop through all potential eye hits
			for (var i in eyes.hits){
				var left:Rectangle = eyes.hits[i];
				// For each eye hit try to find a pair. 
				for (var j in eyes.hits){
					var right:Rectangle = eyes.hits[j];
					if (left == right) continue;
					
					// Only check eyes that are on the right side of the current one
					if (left.x > right.x) {
						continue;
					}
					
					// Left eye on left side and right eye on right side
					var halfPoint:uint = eyesRect.x + eyesRect.width/2;
					if (left.right > halfPoint || right.x < halfPoint) {
						continue;
					}
					
					// Check if the relative location of the eyes are correct
					var xDist:uint = right.x - left.x;
					if (Math.abs(left.y - right.y) > eyesRect.width*0.1 || xDist > eyesRect.width*0.7 || xDist < eyesRect.width*0.3){
						continue;
					}
					
					// Check for the relative size of the eyes
					/*
					if (Math.abs(left.width - right.width) > left.width*0.5 || Math.abs(left.height - right.height) > left.height*0.5){
						continue;
					}*/
										
					var pair:Object = new Object();
					pair.e1 = left;
					pair.e2 = right;
					eyes.pairs.push(pair);
				}
			}
		}
		
		// On every frame, eacg eye models' relevance are decremented.
		private function maintainEyeModels() : void {
			for (var i in eyes.models){
				var m:Object = eyes.models[i];
				m.relevance -= 2;
				if (m.relevance < 1){
					eyes.models.splice(i,1);
					continue;
				}
				if (m.relevance > 20) m.relevance == 20;
				if (m.paired > 20) m.paired == 20;
				
				m.paired -= 1;
				if (m.paired < 1) {
					//eyes.models.splice(i,1);
					//continue;
					m.paired = 0;
				}
			}
		}
		
		
		// Adds a hit to the eye models. If a match is found, increment the relevance of an eye model, if not create a new eye model.
		private function addEyeModel(hit) : void {
			
			for (var i in eyes.models){
				var m:Object = eyes.models[i];
				var dist:uint = Point.distance(m.p, hit.p);
				if (dist < 30 && Math.abs(m.radius-hit.radius) < m.radius*0.2 ){
					m.p = Point.interpolate(hit.p, m.p, 0.9);
					m.radius = (m.radius + hit.radius)/2;
					m.w = (m.w + hit.w)/2;
					m.relevance += 5;
					return;
				}
			}
			// No matching model, so create a new one for the hit.
			var eye:Object = new Object();
			eye.p = hit.p;
			eye.relevance = 5;
			eye.radius = hit.radius;
			eye.w = hit.w;
			eye.paired = 0;
			eyes.models.push(eye);
		}
			

		private function preprocessEyesArea(bmdSrc, bmdDest, eyesRect) : void {
			// Get pixels and loop through them
			var pixels:ByteArray = bmdSrc.getPixels(eyesRect);
			pixels.position = 0;
			var c:uint;
			var cPrev:uint = 100;
			var r:uint;
			var g:uint;
			var b:uint;
			var max:uint;
			var min:uint;
			var sat:uint;
			var chroma:uint;
			while (pixels.bytesAvailable > 0) {
				c = pixels.readUnsignedInt();
				r = c >> 16 & 0xFF;
				g = c >> 8 & 0xFF;
				b = c & 0xFF;
				max = Math.max(r,  b);
				min = Math.min(r,  b);
				chroma = max-min;
				
				// Filter with chromaticity
				if (chroma < MAX_CHROMATICITY || cPrev < MAX_CHROMATICITY) {
					// This is not a skin pixel
					pixels.position -= 4;
					pixels.writeUnsignedInt(0xFF000000);
				} else {
					pixels.position -= 4;
					pixels.writeUnsignedInt(0xFFFFFFFF);					
				}
				cPrev = c;
			}
			pixels.position = 0;
			bmdDest.setPixels(eyesRect, pixels);			
		}
		
		// Finds eye positions
		private function findEyes(bmd, eyesRect) : Array {
			var x:uint;
			var y:uint;
			var c:uint;
			var floodColor:uint = 0xFF00FF00;
			var eyes:Array = [];
			var rect:Rectangle;
			var maxSize:uint = eyesRect.width*0.3;
			var minSize:uint = eyesRect.width*0.05;

			// First find a black area of pixels
			for (y=eyesRect.y; y<eyesRect.bottom; y+=2){
				for (x=eyesRect.x; x<eyesRect.right; x+=2){
					c = bmd.getPixel(x, y);
					if (c == 0xFFFFFF) {
						// Found a potential aread
						floodColor += 1;
						bmd.floodFill(x, y, floodColor);
						rect = bmd.getColorBoundsRect(0xFFFFFFFF, floodColor, true);
						if (rect.width < maxSize && rect.height < maxSize && rect.width > minSize && rect.height > minSize){
							// Found one eye
							eyes.push(rect);
							/*
							var found:Shape = new Shape();
							found.graphics.lineStyle(1, 0xFF0000FF);
							found.graphics.drawRect(rect.x, rect.y, rect.width, rect.height);
							bmd.draw(found);
							*/
						}
					}
				}
			}
			return eyes;
		}
		

		public static function colorsToHex(a:uint, r:uint, g:uint, b:uint):uint{
			return (a << 24) | (r << 16) | (g << 8) | b;
		}
		public static function greyColor(a:uint, vol:uint):uint{
			return colorsToHex(a, vol, vol, vol);
		}
		private static function getHue(r:uint, g:uint, b:uint, max:uint, min:uint, chroma:uint):uint{
			var hue:int = 0;
			if(max == min){
				hue = 0;
			}else if(max == r){
				hue = (60 * ((g-b) / chroma) + 360) % 360;
			}else if(max == g){
				hue = (60 * ((b-r) / chroma) + 120);
			}else if(max == b){
				hue = (60 * ((r-g) / chroma) + 240);
			}
			return hue;
		}
		private static function RGBtoCr(r:uint, g:uint, b:uint) : uint {
            //ycbcr[0] = (byte)((0.299 * (float)rgb[0] + 0.587 * (float)rgb[1] + 0.114 * (float)rgb[2]));
            //ycbcr[1] = (byte)(128 + (byte)((-0.16874 * (float)rgb[0] - 0.33126 * (float)rgb[1] + 0.5 * (float)rgb[2])));
            return 128 + (0.5 * r - 0.41869 * g - 0.08131 * b);
        }
		
		private static function drawToSprite(sprite:Sprite, bmd:BitmapData):void {
			if (sprite.numChildren > 0) sprite.removeChildAt(0);
			sprite.addChildAt(new Bitmap(bmd), 0);
		}
		


	}
}
