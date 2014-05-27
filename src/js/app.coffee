APP = angular.module('moodmusic', ['ngSanitize'])

# weeks
WEEK_MS = 7 * 24 * 60 * 60 * 1000
FINAL_DATE = new Date(2010,0,1).getTime()

# Watch scroll pos
APP.run ($rootScope)->
  pos = 1
  $window = $(window)

  do bindScroll = ->
    $window.one "scroll", ->
    pos = $window.scrollTop()
    $rootScope.$broadcast 'scroll_pos', pos
    setTimeout bindScroll, 100

# Config

# for test injection
APP.constant('WEEK_MS', WEEK_MS)
APP.constant('FINAL_DATE', FINAL_DATE)

APP.constant('soundcloudConfig',{
  dateFormat: "yyyy-MM-dd HH:mm:ss"
  url: "http://api.soundcloud.com/tracks.json?client_id=ad75c94f50f35a7ee18516d1f04191fd&q={query}&created_at[from]={date_from}&created_at[to]={date_to}"
})

APP.constant('tumblrConfig', {
  url:  "http://api.tumblr.com/v2/tagged?tag={query}&api_key=eEB0OHd4PI6PocqaxBtwiZRKXs5fqo3aQqoitxmPAKizjDgwl3&before={date_to}&callback=JSON_CALLBACK"
})

# Services

# These return iterators following the ES6 protocol
APP.factory "SoundCloud", ($http, $q, soundcloudConfig, $filter)->
  class SoundCloudPost
    constructor: (@data)->

    type: "soundcloud"

    url: -> @data.permalink_url

    photo: -> @data.artwork_url?.replace('-large','-t500x500')

    caption: -> @data.title

    date: -> new Date @data.created_at

  {dateFormat, url} = soundcloudConfig

  filter = (date)-> encodeURIComponent $filter('date')(date, dateFormat)

  get = (query)->
    date_to = Date.now()
    date_from = date_to - WEEK_MS
    done = false
    # debounce
    loading = false

    next = ->
      return {done: true} if done

      _url = url
        .replace('{query}',encodeURIComponent(query))
        .replace('{date_from}', filter(date_from))
        .replace('{date_to}', filter(date_to))

      # decrement date range
      date_to = date_from - 1
      date_from = date_to - WEEK_MS

      # convert to Promise
      deferred = $q.defer()

      if loading
        deferred.resolve([])
      else
        loading = true
        $http.get( _url, {cache: true}).success (data)->
          loading = false

          posts = data.map (track)-> new SoundCloudPost track

          deferred.resolve(posts)

      done = date_to < FINAL_DATE
      return {
        value: deferred.promise
        done: done
      }

    return {next}

  # Public API
  return {get}

APP.factory "Tumblr", ($http, $q, tumblrConfig)->
  class TumblrPost
    constructor: (@data)->

    type: "tumblr"

    url: -> @data.post_url

    # 500px width size
    photo: -> @data.photos[0]?.alt_sizes[1]?.url

    caption: -> @data.caption

    date: -> new Date @data.date

  {url} = tumblrConfig

  get = (query)->
    date_to = Date.now()
    date_from = date_to - WEEK_MS
    done = false
    loading = false

    next = ->
      return {done: true} if done

      _url = url
        .replace('{query}',encodeURIComponent(query))
        .replace('{date_to}', Math.floor(date_to / 1000))

      date_to = date_from - 1
      date_from = date_to - WEEK_MS

      deferred = $q.defer()
      $http.jsonp(_url, {cache: true}).success (data)->
        # clean up response
        response = data.response

        photos = response.filter (r)->
          # get only photos
          r.type is "photo" &&
          # filter dates outside range (and convert datestamp)
          r.timestamp > date_from / 1000

        posts = photos.map (photo)-> new TumblrPost photo

        deferred.resolve(posts)

      done = date_to < FINAL_DATE
      return {
        value: deferred.promise
        done: done
      }

    return {next}

  # Public API
  return {get}

# merge iterators
APP.factory "Sources", (SoundCloud, Tumblr, $q)->

  get = (query)->
    done = false

    sc = SoundCloud.get(query)
    tumblr = Tumblr.get(query)

    next = ->
      return {done: true} if done

      _sc = sc.next()
      _tumblr = tumblr.next()

      done = _sc.done || _tumblr.done

      # combine promises
      deferred = $q.defer()

      $q.all({
        soundcloud: _sc.value
        tumblr: _tumblr.value
      }).then (res)->
        # merge results
        newResults = [].concat res.soundcloud, res.tumblr
        # sort results
        newResults.sort (a,b)-> b.date() - a.date()
        deferred.resolve newResults

      value = deferred.promise

      return {value, done}

    return {next}

  return {get}



# Controllers
APP.controller "SearchCtrl", ($scope, Sources)->
  $scope.search = {
    query: "",
    iter: null
    results: []
    get: (valid)->
      return unless valid
      @iter = Sources.get(@query)
  }

# takes an iterator

# TODO: use repeat_expression on directive
#       do something to inject window/el height better
APP.directive "jfInfiniteScroll", ($rootScope, $window)->
  scope = {
    iter: '=jfInfiniteScroll'
  }

  template = """
  <ul class="inifinite-scroll">
    <li class="infinite-scroll-element" ng-repeat="result in results">
      <div ng-transclude></div>
    </li>
  </ul>
  """

  link = (scope, $el, attrs)->
    scope.results = []
    # get next when scroll changes
    loadUntilFull = (e, pos = 1)->
      return unless scope.iter

      window_height = $($window).height()
      result_height = $el.height()

      # return if results fill window and then some
      return if result_height > (window_height * 2) + pos

      scope.iter.next().value?.then (res)->
        scope.results = scope.results.concat res
        setTimeout loadUntilFull, 100

    # clear results on changes
    scope.$watch 'iter', (n,p)->
      scope.results = [] unless n is p
      loadUntilFull()

    $rootScope.$on "scroll_pos", loadUntilFull

  {scope, link, template, restrict: 'EA', transclude: true, replace: true}



APP.directive "jfSourceElement", ->
  scope = {
    el: "=jfSourceElement"
  }

  template = """
    <a ng-href="{{el.url()}}">
      <img ng-src="{{el.photo()}}">
      <div ng-bind-html="el.caption()"></div>
      <time>{{el.date()|date:'mediumDate'}}</time>
    </a>
  """

  {scope, template, restrict: 'EA', replace: true}