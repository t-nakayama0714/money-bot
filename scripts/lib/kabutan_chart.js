var system = require('system');
var args = system.args;
var url = args[1];
var savePath = args[2]

var page = require('webpage').create();

// 画面サイズ
page.viewportSize = {
  width: 1920,
  height: 1080
};

// 切り抜き位置(株探チャート用)
page.clipRect = {
  top: 643,
  left: 475,
  width: 640,
  height: 402
};

// スクリーンショット取得
page.open(url, function() {
    page.render(savePath);
    phantom.exit();
});
