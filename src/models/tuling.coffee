define ['restler','conf/config'], (rest,config) ->
  ask = (userId,question,cb) ->
    rest.get(config.tuling.url,
      query:
        key: config.tuling.key
        info: question
        userid: userId
    ).on "complete", (result) ->
      result = JSON.parse(result)
      message = { msgType: 'text' }
      switch result.code
        when 100000 then message.content = result.text
        when 200000
          message = 
            msgType: 'news'
            articles: [{title: result.text,url: result.url}]
        when 305000
          message = 
            msgType: 'news'
            articles: []
          for train in result.list
            break if message.articles.length > 10
            message.articles.push
              title: "#{train.trainnum} #{train.starttime}-#{train.endtime}"
              description: "车次: #{train.trainnum}\n始发站: #{train.start}\n发车时间: #{train.starttime}\n终点站: #{train.terminal}\n到站时间: #{train.endtime}"
              url: train.detailurl
              picUrl: train.icon
        when 302000
          message = 
            msgType: 'news'
            articles: []
          for news in result.list
            break if message.articles.length > 10
            message.articles.push
              title: news.article
              url: news.detailurl
        when 308000
          message = 
            msgType: 'news'
            articles: []
          for dish in result.list
            break if message.articles.length > 10
            message.articles.push
              title: dish.name
              description: dish.info
              url: dish.detailurl
              picUrl: dish.icon
        else message.content = result.text
      cb message
  { ask: ask }