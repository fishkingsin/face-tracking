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
		
		


		private var EYE_DETECTION_AREA		: Rectangle = new Rectangle(0,0, VIDEO_WIDTH, VIDEO_HEIGHT/2);
		private var eyes					: Object = new Object();
		private var faceBounds				: Rectangle;
		
		
		private var DEFAULT_POINT			: Point = new Point(0,0);
		private var debugCount 				: Number = 0;
		private var fps		 				: uint = 0;
		private var fpsCount 				: uint = 0;
		private var fpsTimer 				: uint = 0;
		
		private var COLOR_THRESHOLD			: uint = 0x00888888;
		
		
		
		
		public function FaceTracking() {
			
			slider1_mc.value = 10;
			slider2_mc.value = 7;
						
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
			
			COLOR_THRESHOLD = greyColor(0, slider2_mc.value*25);
			
			var a:Number = slider1_mc.value/slider1_mc.maximum * 11;
			var b:Number = 3.5 - (slider1_mc.value/slider1_mc.maximum * 698.5);
			var matrix:Array = new Array();
            matrix = matrix.concat([a, 0, 0, 0, b]); // red
            matrix = matrix.concat([0, a, 0, 0, b]); // green
            matrix = matrix.concat([0, 0, a, 0, b]); // blue
            matrix = matrix.concat([0, 0, 0, 1, 0]); // alpha
			var contrastCmf:ColorMatrixFilter = new ColorMatrixFilter(matrix);
			var GAUSSIAN_3BY3:ConvolutionFilter = new ConvolutionFilter(3,3,[ 1,2,1,
 																		 	  2,4,2,
																			  1,2,1], 16);

			//	Copy the latest still-frame of the webcam video into the BitmapData object for detection
			bmBase.draw(video1);
			
			
			// Filter and process the base image to detect the face area using the skin color
			
			var scaleAmount:Number = 2;
			var scale:Number = 1/scaleAmount;
			bmFiltered = new BitmapData(VIDEO_WIDTH*scale, VIDEO_HEIGHT*scale);
			var m:Matrix = new Matrix();
		    m.scale(scale, scale);
			bmFiltered.draw(bmBase, m);
			//bmFiltered.applyFilter(bmFiltered, rect, new Point(0,0), GAUSSIAN_3BY3);
			bmFiltered.applyFilter(bmFiltered, rect, new Point(0,0), blur);
			filterSkin(bmFiltered);
			//bmFiltered.threshold(bmFiltered, rect, new Point(0,0), ">", 0x66, 0xFFFFFFFF, 0xFF);
			
			// Find the approximate face position and it's rectangle
			faceBounds = findFacePositions(bmFiltered);
			faceBounds.x *= scaleAmount;
			faceBounds.y *= scaleAmount;
			faceBounds.width *= scaleAmount;
			faceBounds.height *= scaleAmount;

			// Make the pic bigger
			m.identity();
		    m.scale(scaleAmount, scaleAmount);
			bmFace.draw(bmFiltered, m);			
			
			// Create a green bordered face rectangle helper shape
			var faceRect:Shape = new Shape();
			faceRect.graphics.lineStyle(1, 0x0000FF);
			faceRect.graphics.drawRect(faceBounds.x, faceBounds.y, faceBounds.width, faceBounds.height);
			
			// Draw the face area helper image
			drawToSprite(sprite3, bmFace);
			
			
			
			

			// Find edges
			/*
			bmEdges = bmBase.clone();
			var third:Number = 1 / 3;
			var blueScaleArray:Array = [third, third, third, 0, 0,
										third, third, third, 0, 0,
										third, third, third, 0, 0,
										0, 0, 0, 1, 0];
			
			var blueScaleFilter:ColorMatrixFilter = new ColorMatrixFilter(blueScaleArray);
			bmEdges.applyFilter(bmEdges, faceBounds, faceBounds.topLeft, blueScaleFilter);			
			//bmEdges.applyFilter(bmEdges, faceBounds, faceBounds.topLeft, GAUSSIAN_3BY3);
			
			var HORIZONTAL_SOBEL:ConvolutionFilter = new ConvolutionFilter(3,3,
			  [-1,-2,-1,
			    0, 0, 0,
				1, 2, 1], 1, 127);
			//			  [ 1, -1,
			//			    1, -1], 1, 127);
			var VERTICAL_SOBEL:ConvolutionFilter = new ConvolutionFilter(3,3,
			  [ 1, 0,-1,
			    2, 0,-2,
			    1, 0,-1], 1, 127);
			//			  [ 1, 1,
			//			    -1,-1], 1, 127);
			
			var horizontalEdge:BitmapData = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
			horizontalEdge.applyFilter(bmEdges, faceBounds, faceBounds.topLeft, HORIZONTAL_SOBEL);
			var verticalEdge:BitmapData = new BitmapData(VIDEO_WIDTH, VIDEO_HEIGHT);
			verticalEdge.applyFilter(bmEdges, faceBounds, faceBounds.topLeft, VERTICAL_SOBEL);
			
			bmEdges.fillRect(rect, 0xFFFFFFFF);
			//bmEdges.threshold(horizontalEdge, faceBounds, faceBounds.topLeft, "<", 0x22, 0xFF000000, 0xFF);
			bmEdges.threshold(horizontalEdge, faceBounds, faceBounds.topLeft, ">", 0xDD, 0xFF000000, 0xFF);
			bmEdges.threshold(verticalEdge, faceBounds, faceBounds.topLeft, "<", 0x22, 0xFF000000, 0xFF);
			bmEdges.threshold(verticalEdge, faceBounds, faceBounds.topLeft, ">", 0xDD, 0xFF000000, 0xFF);
			drawToSprite(sprite6, bmEdges);
			drawToSprite(sprite5, verticalEdge);
			//findEdges(bmEdges, faceBounds);
			//drawToSprite(sprite6, bmEdges);
			*/


			/*
			// Contrasted
			bmContrast = bmBase.clone();			
			bmContrast.applyFilter(bmContrast, faceBounds, faceBounds.topLeft, contrastCmf);
			//drawToSprite(sprite5, bmContrast);

			// Preprocess the detected face area for eye detection
			bmEyes.fillRect(rect, 0xFFFFFFFF);
			bmContrast.applyFilter(bmContrast, faceBounds, faceBounds.topLeft, blur);
			bmEyes.threshold(bmContrast, faceBounds, faceBounds.topLeft, "<", COLOR_THRESHOLD, 0xFF000000, 0x00FFFFFF);
			drawToSprite(sprite1, bmEyes);
			*/
			//bmEyes = bmFace.clone();
			bmEyes.fillRect(rect, 0xFFFFFFFF);
			drawToSprite(sprite1, bmEyes);
			
			// Draw the base image with the detected areas
			bmFinal = bmBase;
			bmFinal.draw(faceRect);			
			drawToSprite(sprite4, bmFinal);
						
			// Find the potential eye shapes. These are round shapes. Add these eyes into the eye models list.
			findEyes(bmEyes);
			eyes.models.sort(sortByRelevance);
			
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
		
		
		function findEdges(bmd, rect):void {
			// Get pixels and loop through them
			var pixels:ByteArray = bmd.getPixels(rect);
			pixels.position = 0;
			var c:uint;
			var r:uint;
			var g:uint;
			var b:uint;
			var prevB:uint;
			
			c = pixels.readUnsignedInt();
			prevB = c & 0xFF;
			
			while (pixels.bytesAvailable > 0) {
				c = pixels.readUnsignedInt();
				// Normalize the color
				r = c >> 16 & 0xFF;
				g = c >> 8 & 0xFF;
				b = c & 0xFF;
				
				if (Math.abs(b-prevB) > 100) {
					// Found an edge
					pixels.position -= 4;
					pixels.writeUnsignedInt(0xFF00FF00);
					pixels.writeUnsignedInt(0xFF00FF00);
					//pixels.position += 4;
				}
				prevB = b;
				pixels.position += 4;
			}
			pixels.position = 0;
			bmd.setPixels(rect, pixels);			
		}		
		

		// Finds all potential face positions
		private function findFacePositionsOld(bmd) : Rectangle {
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
			
			// First find the widest black line
			var hLimit:uint = h*0.8;
			for (y=0; y<hLimit; y++){
				for (x=0; x<w; x++){
					c = bmd.getPixel(x, y);
					if (c != 0 || x == w-1) {
						if (currentWidth > target.w){
							target.w = currentWidth;
							if (x == w-1) target.w++;
							target.y = y;
							target.x = x - currentWidth;
						}
						currentWidth = 0;
					} else {
						currentWidth++;
					}
				}
			}
			bmd.fillRect(new Rectangle(target.x, target.y, target.w, 1), 0xFFFF0000);
			
			// Now we know where is the widest point. Next let's find the highest point on the widest line.
			var maxUp:int = 0;
			var maxDown:int = 0;
			var currentHeight:int = 0;
			for (x=target.x; x<target.x+target.w; x++){
				// First look up
				y = target.y;
				while (y-- > 0){
					//trace('y=' + y);
					c = bmd.getPixel(x, y);
					if (c != 0 || y == 0) {
						if (currentHeight > maxUp){
							maxUp = currentHeight;
						}
						currentHeight = 0;
					} else {
						currentHeight++;
					}
				}
				// Then look down
				y = target.y;
				while (++y < h){
					c = bmd.getPixel(x, y);
					if (c != 0 || y == h-1) {
						if (currentHeight > maxDown){
							maxDown = currentHeight;
						}
						currentHeight = 0;
					} else {
						currentHeight++;
					}
				}
				
			}			
			
			// Finally we can make a rectangle out of the data
			
			var boundsRect:Rectangle = new Rectangle(target.x, target.y-maxUp, target.w, maxUp+maxDown);
			var rect:Shape = new Shape();
			rect.graphics.lineStyle(1, 0x0000FF);
			rect.graphics.drawRect(boundsRect.x, boundsRect.y, boundsRect.width, boundsRect.height);
			bmd.draw(rect);
			return boundsRect;
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
				// Normalize the color
				r = c >> 16 & 0xFF;
				g = c >> 8 & 0xFF;
				b = c & 0xFF;
				max = Math.max(r, g, b);
				min = Math.min(r, g, b);
				chroma = max-min;
				
				// Filter with chromatisity
				if (skin_chroma_mc.selected) {
					if (chroma < 50) {
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
		
		private function drawEyePairs(bmd:BitmapData, drawCount:uint = 100) : void {
			for (var i in eyes.pairs){
				var pair:Object = eyes.pairs[i];

				var rect:Shape = new Shape();    
				rect.graphics.lineStyle(2, 0xFF0000);
				rect.graphics.drawRect(pair.e1.p.x-pair.e1.radius, pair.e1.p.y-pair.e1.radius, pair.e1.w, pair.e1.w);
				bmd.draw(rect);
				
				rect.graphics.drawRect(pair.e2.p.x-pair.e2.radius, pair.e2.p.y-pair.e2.radius, pair.e2.w, pair.e2.w);
				bmd.draw(rect);
				if (--drawCount == 0) return;
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
		
		// Find eye pairs from the eye models based on relative location and size
		private function findEyePairs() : void {
			eyes.pairs =[];

			// Loop through all potential eye models
			for (var i in eyes.models){
				var m:Object = eyes.models[i];
				if (m.relevance < 10) continue;
				// For each eye model try to find a pair. 
				for (var j in eyes.models){
					var other:Object = eyes.models[j];
					if (m == other) continue;
					if (other.relevance < 10) continue;
					
					// Check if the relative location of the eyes are correct
					var xDist:uint = Math.abs(m.p.x - other.p.x);
					if (Math.abs(m.p.y - other.p.y) > 40 || xDist > faceBounds.width || xDist < faceBounds.width*0.3){
						continue;
					}
					
					// Check for the relative size of the eyes
					if (Math.abs(m.radius - other.radius) > m.radius*0.2){
						continue;
					}
					
					// These models qualify as pairs
					m.paired += 15;
					other.paired += 15;
					
					// Since these models are pairs, they are more relevant
					//m.relevance++;
					//other.relevance++;
					
					var pair:Object = new Object();
					pair.relevance = m.paired + other.paired;
					if (m.p.x < other.p.x) {
						pair.e1 = m;
						pair.e2 = other;
					} else {
						pair.e1 = other;
						pair.e2 = m;
					}
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
			

		// Finds eye positions
		// Find eye positions by looking for monitor reflection on the eye. So find circle shaped black balls that have a white center.
		// Don't find up only left, right, down and diagonally down.
		private function findEyes(bmd) : void {
			bmTarget = bmd;
			var x:uint = 0;
			var hits:Array = [];
			eyes.hits = [];
			
			for (var y:uint=EYE_DETECTION_AREA.top; y<EYE_DETECTION_AREA.bottom; y+=1){
				x = EYE_DETECTION_AREA.left;
				while (x<EYE_DETECTION_AREA.right){
					var hit:Object = findBlack(x, y);
					
					if (hit == null) {
						// End of the horizontal line. Go to next line.
						break;
					}
					if (hit.w > 5 && hit.w < 20) {
						// It was a hit
						//bmTarget.fillRect(new Rectangle(hit.x1, hit.p.y, hit.w, 1), 0xFFFF9900);
						
						if (checkCircleShape(hit)){
							bmTarget.fillRect(new Rectangle(hit.x1, hit.p.y, hit.w, 1), 0xFFFF0000);
							hit.rank = 0;
							addEyeModel(hit);
							eyes.hits.push(hit);
						}
					}
					x = hit.x2+1;
				}
			}
		}
		
		// Finds black pixels on x axis. 
		private function findBlack(xStart, yStart): Object {
			var p:Point = new Point(xStart, yStart);
			var color:uint;
			
			// Search for black, stop if found.
			while (bmTarget.getPixel32(p.x, p.y) != 0xFF000000){
				if (++p.x >= VIDEO_WIDTH) return null;
			}
			
			var hit:Object = new Object();
			hit.x1 = p.x;

			// Search for the end of black, stop if found.
			while (p.x < VIDEO_WIDTH){
				color = bmTarget.getPixel32(p.x, p.y);
				if (color != 0xFF000000) {
					// Check if the next pixel is black, if so then discard the lonely one white pixel
					if (bmTarget.getPixel32(++p.x, p.y) == 0xFF000000) {
						continue;
					}
					break;
				}
				p.x++;
			}
			hit.x2 = p.x - 1;
			hit.w = hit.x2 - hit.x1;
			hit.radius = hit.w / 2;			
			hit.p = new Point(hit.x1 + hit.radius, yStart);
			return hit;
		}
		
		
		// Check for a circle shape. Look down and diagonally down.
		private function checkCircleShape(hit) : Boolean {
			var lengths:Array = [];
			var lenDiffs:Array = [0.3, 0.3, 0.3, 0.3, 0.6];
			var vectors:Array = [new Point(0, 1), new Point(-1, 1), new Point(1, 1), new Point(0, -1)];
			var len:int;

			for (var i in vectors){
				len = checkVectorHit(hit, vectors[i], hit.radius*(1+lenDiffs[i]));
				if (len > hit.radius*(1+lenDiffs[i]) || len < hit.radius*(1-lenDiffs[i])) {
					return false;
				}
				lengths.push(len);
				if (len == -1) return false;
			}
			
			for (var a in vectors){
				len = lengths[a];
				var line:Shape = new Shape();    
				line.graphics.lineStyle(1, 0x00FF00);
				line.graphics.moveTo(hit.p.x, hit.p.y);
				line.graphics.lineTo(hit.p.x+vectors[a].x*len, hit.p.y+vectors[a].y*len);
				bmTarget.draw(line);
			}			
			
			return true;
		}

		
		// Finds black pixels on the vector. Returns the length until the hit point or -1 for not found after maxDist has been moved.
		private function checkVectorHit(hit, vec, maxDist) : int {
			var p:Point = new Point(hit.p.x,hit.p.y);
			var dist:uint = 0;
			vec.normalize(1);

			while (p.y < VIDEO_HEIGHT && p.y > 0 && dist < maxDist){
				if (bmTarget.getPixel32(p.x, p.y) != 0xFF000000) {
					// Check if the next pixel is black, if so then discard the lonely one white pixel
					p = p.add(vec);
					if (bmTarget.getPixel32(p.x, p.y) != 0xFF000000) {
						return dist;
					}

				} else {
					p = p.add(vec);
				}
				dist++;
			}				
			return -1;
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
