import * as THREE from '/js/threejs/three.module.js';
import { OrbitControls } from '/js/threejs/controls/OrbitControls.js';
import { RoomEnvironment } from '/js/threejs/environments/RoomEnvironment.js';

var stopAnimation;
var resizeHandler;

function createPastureBackgroundTexture() {
    var canvas = document.createElement('canvas');
    canvas.width = 2048;
    canvas.height = 1024;

    var ctx = canvas.getContext('2d');
    var sky = ctx.createLinearGradient(0, 0, 0, canvas.height * 0.7);
    sky.addColorStop(0, '#1b75d0');
    sky.addColorStop(0.45, '#6cb7ff');
    sky.addColorStop(1, '#d9f4ff');
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    function cloud(x, y, scale, alpha) {
        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.fillStyle = '#ffffff';
        ctx.beginPath();
        ctx.ellipse(x, y, 96 * scale, 26 * scale, 0, 0, Math.PI * 2);
        ctx.ellipse(x + 74 * scale, y - 8 * scale, 64 * scale, 22 * scale, 0, 0, Math.PI * 2);
        ctx.ellipse(x - 62 * scale, y - 6 * scale, 54 * scale, 19 * scale, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
    }

    cloud(380, 160, 1.1, 0.72);
    cloud(1240, 118, 0.8, 0.58);
    cloud(1710, 260, 1.25, 0.62);

    var distantHill = ctx.createLinearGradient(0, canvas.height * 0.45, 0, canvas.height);
    distantHill.addColorStop(0, '#70c757');
    distantHill.addColorStop(1, '#238226');
    ctx.fillStyle = distantHill;
    ctx.beginPath();
    ctx.moveTo(0, 690);
    ctx.bezierCurveTo(360, 490, 700, 590, 1010, 510);
    ctx.bezierCurveTo(1340, 426, 1650, 510, 2048, 424);
    ctx.lineTo(2048, 1024);
    ctx.lineTo(0, 1024);
    ctx.closePath();
    ctx.fill();

    var nearHill = ctx.createLinearGradient(0, canvas.height * 0.55, 0, canvas.height);
    nearHill.addColorStop(0, '#a8dd58');
    nearHill.addColorStop(0.45, '#57ad28');
    nearHill.addColorStop(1, '#146d1d');
    ctx.fillStyle = nearHill;
    ctx.beginPath();
    ctx.moveTo(0, 792);
    ctx.bezierCurveTo(360, 652, 640, 720, 930, 620);
    ctx.bezierCurveTo(1270, 498, 1540, 620, 2048, 544);
    ctx.lineTo(2048, 1024);
    ctx.lineTo(0, 1024);
    ctx.closePath();
    ctx.fill();

    ctx.globalAlpha = 0.28;
    ctx.strokeStyle = '#f2ffd5';
    ctx.lineWidth = 2;
    for (var i = 0; i < 120; i++) {
        var x = (i * 73) % canvas.width;
        var y = 650 + ((i * 47) % 330);
        ctx.beginPath();
        ctx.moveTo(x, y + 20);
        ctx.quadraticCurveTo(x + 22, y - 16, x + 58, y + 4);
        ctx.stroke();
    }
    ctx.globalAlpha = 1;

    var texture = new THREE.CanvasTexture(canvas);
    texture.encoding = THREE.sRGBEncoding;
    texture.anisotropy = 4;
    return texture;
}

window.appJsFunctions = {

    cleanup: function () {
        stopAnimation = true;

        // invoking an event which has references to disposed object(s) looks start GC process.
        if (resizeHandler) {
            // not calling directly but using setTimeout ensures object(s) disposed.
            window.setTimeout(resizeHandler);
        }
    },

    loadScene: function () {

        var container = document.getElementById('index-3d-viewer');
        if (!container) {
            console.log('no container element found.');
            return;
        }

        var viewerWidth = container.clientWidth;
        var viewerHeight = container.clientHeight;

        var renderer = new THREE.WebGLRenderer({ antialias: true });
        renderer.setPixelRatio(window.devicePixelRatio);
        renderer.setSize(viewerWidth, viewerHeight);
        renderer.outputEncoding = THREE.sRGBEncoding;
        container.appendChild(renderer.domElement);

        var camera = new THREE.PerspectiveCamera(40, viewerWidth / viewerHeight, 0.1, 100);
        camera.position.set(1, 1, -4);

        if (viewerWidth < viewerHeight) {
            camera.position.set(1, 1, -12);
        }

        var controls = new OrbitControls(camera, container);
        controls.target.set(0, 0.5, 0);
        controls.update();

        var environment = new RoomEnvironment();
        var pmremGenerator = new THREE.PMREMGenerator(renderer);

        var scene = new THREE.Scene();
        scene.background = createPastureBackgroundTexture();
        scene.environment = pmremGenerator.fromScene(environment).texture;
        scene.fog = new THREE.Fog(0xd9f4ff, 14, 55);

        var model;

        var loader = new THREE.ObjectLoader();
        loader.load("/3d/model.json", function (object) {
            model = object;
            scene.add(model);
        });

        var mouse = new THREE.Vector2();

        var handler = function (e) {
            var element = e.currentTarget;
            var x = e.clientX - element.offsetLeft;
            var y = e.clientY - element.offsetTop;
            var w = element.offsetWidth;
            var h = element.offsetHeight;

            // for touch event
            if (!x) {
                var touch = e.changedTouches[0];
                x = touch.clientX - element.offsetLeft;
                y = touch.clientY - element.offsetTop;
            }

            // regularization from -1 to 1
            mouse.x = (x / w) * 2 - 1;
            mouse.y = -(y / h) * 2 + 1;

            var raycaster = new THREE.Raycaster();
            raycaster.setFromCamera(mouse, camera);

            var intersects = raycaster.intersectObjects(model.children);
            if (intersects.length > 0) {
                //console.log(intersects);
                //console.log(intersects[0].object.name);

                var url;
                var objectName = intersects[0].object.name;
                switch (objectName) {
                    case 'Twitter':
                        url = 'https://twitter.com/with_bugs';
                        break;
                    case 'YouTube':
                        url = 'https://www.youtube.com/channel/UCJZeq1xYxpLn_SlOUnQ8XOA';
                        break;
                    case 'Instagram':
                        url = 'https://www.instagram.com/withbugs/';
                        break;
                    case 'GitHub':
                        url = 'https://github.com/withbugs';
                        break;
                    case 'Bot':
                        url = 'http://withbugsbot.azurewebsites.net/';
                        break;
                }

                if (url) {
                    window.open(url);
                }
            }
        }

        container.addEventListener('click', handler);
        container.addEventListener('touchend', handler);
        
        stopAnimation = false;

        var animate = function () {
            if (stopAnimation) {
                console.log('stopping animation');
                return;
            }

            requestAnimationFrame(animate);
            renderer.render(scene, camera);
        };

        // resize event handler is added each time 'loadScene' function is called.
        // to avoid keep adding handlers, remove a handler when referencing disposed object like 'container.clientWidth'.
        // and have a handler reference as 'resizeHandler' to call in cleanup function to remove a handler and kick GC process.
        var f;

        window.addEventListener('resize', f = () => {

            //console.log('resized');

            var newWidth = container.clientWidth;
            var newHeight = container.clientHeight;

            camera.aspect = newWidth / newHeight;
            camera.updateProjectionMatrix();
            renderer.setSize(newWidth, newHeight);

            //console.log(newWidth);
            if (newWidth == 0) {
                window.removeEventListener('resize', f);
                console.log('event removed');
                return;
            }
        });

        resizeHandler = f;

        animate();
    }
};
