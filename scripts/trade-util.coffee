# 各種パッケージ
childProcess = require('child_process')
phantomjs = require('phantomjs-prebuilt')
path = require('path')
FS = require('fs')

# 励ましと煽りの言葉たち
responses = ["ﾜﾛｽ", "諦めんなよ！！！", "がんばれ", "気のせいやで", "切り替えよう", "かなしい"]
random_rate = 0.9

# 株探業績に応じた色のリスト 未定, 急上昇, 上昇, 停滞, 下降, 急下降, なし
perf_color = ["#BDBDBD", "#FF0000", "#FE9A2E", "#01DF01", "#0000FF", "#8904B1", "#FFFFFF"]

# 改行を含む文字列に対して各行で正規表現マッチを行う
# マッチオブジェクトの入った配列が返される
matchRegex = (str, re) ->
  lines = str.split("\n")
  result = []
  for line in lines
    match = line.match(re)
    if match?
      result.push(match)
  return result

# 文字列全体に対して正規表現マッチを行う
# マッチオブジェクト単体が返される
matchMultiRegex = (str, re) ->
  match = str.match(re)
  return match

# 0から引数未満のランダムな整数を得る
random = (n) ->
  Math.floor(Math.random() * n)

module.exports = (robot) ->
  # 銘柄コードに対応する株の情報を返す
  robot.hear /(?:[^\,]\s|^)([0-9]{4})(?:\s|$)/g, (msg) ->
    for line in msg.match
      # なぜか数字より前の文字列が入るのでさらに取り除く
      code = matchRegex(line, /(?:[^\,]?\s|^)([0-9]{4})(?:\s|$)/)[0][1]

      # 日足株価の3ページ目を使うことで、60営業日前の価格が取得できる
      url = "https://kabutan.jp/stock/kabuka?code=#{code}&ashi=day&page=3"
      robot.http(url)
        .get() (err, res, body) ->
          if (err?)
            robot.logger.error(err)
            return msg.send '銘柄情報の取得に失敗しました'

          if (!body)
            return msg.send "指定銘柄(#{code})情報が見つかりませんでした"

          # bodyから各種情報の取得
          title = matchRegex(body, /<title>(.*)：.*<\/title>/)[0][1]
          price = matchRegex(body, /<td width="110" class="kobetsu_data_table1_kabuka">([\.,0-9]+円)<\/td>/)[0][1]
          priceup = matchRegex(body, /<td width="80" style="text-align:right;">(?:<span class="(?:up|down)">)?([+-]?[\.,0-9]+)(?:<\/span>)?<\/td>/)[0][1]
          pctup = matchRegex(body, /<td width="80" style="text-align:right;">\((?:<span class="(?:up|down)">)?([+-]?[\.0-9]+)(?:<\/span>)?%\)<\/td>/)[0][1]
          ratios = matchRegex(body, /<td>([\.,－0-9]+)<span style="font-size:9px">.<\/span><\/td>/)
          fullpath = matchRegex(body, /<li><a href="(\/stock\/chart\?code=[0-9]+)" title="チャート">チャート<\/a><\/li>/)[0][1]
          settle_date = matchMultiRegex(body, /決算発表予定日\r\n&nbsp;([0-9]{4}\/[0-9]{2}\/[0-9]{2})<\/div>/)
          base_price = matchMultiRegex(body, /<td style="text-align:center;">[0-9]{2}\/[0-9]{2}\/[0-9]{2}<\/td>\r\n(?:<td>([\.,0-9]+)<\/td>\r\n){4}(?:<td>.*<\/td>\r\n){3}<\/tr>\r\n<tr>\r\n<td style="text-align:center;">/)
          performance = matchRegex(body, /gyouseki_([0-9]).gif/)[0]

          # 一部例外があるため個別にハンドリング
          perf_index = if performance then performance[1] else "6"
          settle = if settle_date then "決算発表予定日: *#{settle_date[1]}*" else ""

          # ベース値と現在価格の比率を出す
          base_ratio = ( parseInt(price.replace(/,/g, ""), 10) / parseInt(base_price[1].replace(/,/g, ""), 10) - 1 ) * 100

          # 本文の構成
          msg_body = "PER: *#{ratios[0][1]}倍*, PBR: *#{ratios[1][1]}倍*, 利回り: *#{ratios[2][1]}%*, 信用倍率: *#{ratios[3][1]}倍*, Q成長率: *#{base_ratio.toFixed(2)}%*"

          # Attachmentsの構成
          data =
            attachments: [
              color: perf_color[perf_index]
              title: "#{title} : #{price} (#{priceup}, #{pctup}%)"
              title_link: "https://kabutan.jp#{fullpath}"
              pretext: settle
              text: msg_body
              mrkdwn_in: [
                "text",
                "pretext"
              ]
            ]

          # レスポンス
          # hubot-slack4系からこの送り方でよくなった
          msg.send data

  # 指定銘柄コードのチャート画像を返す
  robot.hear /([0-9]{4})$/i, (msg) ->
    code = msg.match[1]
    url = "https://kabutan.jp/stock/chart?code=#{code}"
    filetitle = "#{code}_daily_chart"
    filepath = "stock_image/#{code}.png"

    childArgs = [
      path.join(__dirname, './lib/kabutan_chart.js')
      url
      filepath
    ]

    # 指定URLから画像を生成する(処理自体はscreenshot.js)
    childProcess.execFile phantomjs.path, childArgs, (err, stdout, stderr) ->
      channel = msg.envelope.room

      # 画像をアップロードする
      cmd = "curl -F filename=#{filetitle} -F file=@stock_image/#{code}.png -F channels=#{channel} -F token=#{process.env.HUBOT_SLACK_TOKEN} https://slack.com/api/files.upload"
      childProcess.exec cmd, (err, stdout, stderr) ->
        if err
          msg.send "画像のアップロードに失敗しました"

        # 画像を削除する
        FS.unlinkSync(filepath)

　　# 悩める子羊に光を与える
  robot.hear /悩/i, (msg) ->
    url = "https://www.mo-ney.net/about/proverb/"
    robot.http(url)
      .get() (err, res, body) ->
        if (err?)
          robot.logger.error(err)
          return msg.send '格言一覧の取得に失敗しました'

        # 格言を1つ選ぶ
        proverbs = matchRegex(body, /<div class="yogo_title_prob">(<a href=".*<\/a>)<\/div>/)
        row_proverbs = proverbs[random(proverbs.length)][1].split("</a>  ")
        proverb_url = matchRegex(row_proverbs[random(row_proverbs.length)], /<a href="(.*)">.*(?:$|<\/a>$)/)[0][1]

        robot.http(proverb_url)
          .get() (proverb_err, proverb_res, proverb_body) ->
            if (proverb_err?)
              robot.logger.error(proverb_err)
              return msg.send '格言本文の取得に失敗しました'

            # 格言名と解説を抜き出す
            proverb = matchRegex(proverb_body, /<h1>.*『(.*)』.*<\/h1><p><p>(.*)<\/p>$/)[0]
            proverb_title = proverb[1]
            proverb_comment = proverb[2]

        　　  # Attachmentsの構成
            data =
              attachments: [
                color: "#01DF01"
                title: proverb_title
                title_link: proverb_url
                pretext: responses[random(responses.length)]
                text: proverb_comment
                mrkdwn_in: [
                  "text",
                  "pretext"
                ]
              ]

            # レスポンス
            # hubot-slack4系からこの送り方でよくなった
            msg.send data