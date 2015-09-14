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
            article =
              description: "车次: #{train.trainnum}\n始发站: #{train.start}\n发车时间: #{train.starttime}\n终点站: #{train.terminal}\n到站时间: #{train.endtime}"
              url: train.detailurl
            message.articles.push article
        when 302000
          message = 
            msgType: 'news'
            articles: []
          for news in result.list
            message.articles.push
              title: news.source
              description: news.article
              url: news.detailurl
        when 308000
          message = 
            msgType: 'news'
            articles: []
          for dish in result.list
            message.articles.push
              title: dish.name
              description: dish.info
              url: dish.detailurl
        else message.content = result.text
      cb message
  { ask: ask }