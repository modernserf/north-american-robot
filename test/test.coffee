describe "moodmusic", ->
  beforeEach ->
    module('moodmusic')


  # Services
  describe "SoundCloud", ->
    SoundCloud = null
    config = null
    httpBackend = null
    query = "hamster"
    iterator = null
    WEEK_MS = 7 * 24 * 60 * 60 * 1000
    $filter = null

    testData = [{
      created_at: '2010-01-01'
    },{
      created_at: '2012-01-01'
    }]

    beforeEach ->
      inject ($httpBackend, _SoundCloud_, _soundcloudConfig_, _$filter_)->
        SoundCloud = _SoundCloud_;
        httpBackend = $httpBackend
        config = _soundcloudConfig_
        $filter = _$filter_

    it "gets tracks with a query", ->
      # setup


      {dateFormat, url} = config
      date_to = Date.now()
      date_from = date_to - WEEK_MS

      filter = (date)-> encodeURIComponent $filter('date')(date, dateFormat)

      this_url = url
        .replace('{query}',query)
        .replace('{date_from}', filter(date_from))
        .replace('{date_to}', filter(date_to))

      httpBackend.expectGET(this_url).respond(testData)

      # call
      result = null
      iterator = SoundCloud.get(query)
      next = iterator.next()

      next.value.then (response)->
        result = response.map (r)-> r.data

      httpBackend.flush()

      expect(result).toEqual(testData)

    it "gets previous tracks on each iteration"


  describe "Tumblr", ->
    Tumblr = null
    config = null
    httpBackend = null
    query = "hamster"
    iterator = null

    beforeEach ->
      inject ($httpBackend, _Tumblr_, _tumblrConfig_)->
        Tumblr = _Tumblr_;
        httpBackend = $httpBackend
        config = _tumblrConfig_

    it "gets tagged photo posts in a date range", ->
      {url} = config

      # setup
      today = Math.floor(Date.now() / 1000)
      agesAgo = new Date(2010,0,1).getTime() / 1000

      testData = {
        response: [
          {
            type: "text"
            timestamp: today
          }
          {
            type: "photo"
            timestamp: agesAgo
          }
          {
            type: "photo"
            timestamp: today
          }
        ]
      }

      expectedResponse = [
        {
          type: "photo"
          timestamp: today
        }
      ]

      query = "hamster"

      this_url = url
        .replace('{query}',encodeURIComponent(query))
        .replace('{date_to}', today)

      httpBackend.expectJSONP(this_url).respond(testData)

      # call
      result = null
      iterator = Tumblr.get(query)
      next = iterator.next()

      next.value.then (response)->
        result = response.map (r)-> r.data

      httpBackend.flush()

      expect(result).toEqual(expectedResponse)

    it "decrements the date range with each iteration"

  describe "Sources", ->

    it "merges promise iterators into a single promise iterator"

  # Directives
  describe "jf-infinite-scroll", ->

    it "removes elements that are not visible"

    it "requests elements that will become visible"
