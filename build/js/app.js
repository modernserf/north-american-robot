(function() {
  var APP, FINAL_DATE, WEEK_MS;

  APP = angular.module('moodmusic', ['ngSanitize']);

  WEEK_MS = 7 * 24 * 60 * 60 * 1000;

  FINAL_DATE = new Date(2010, 0, 1).getTime();

  APP.run(function($rootScope) {
    var $window, bindScroll, pos;
    pos = 1;
    $window = $(window);
    return (bindScroll = function() {
      $window.one("scroll", function() {});
      pos = $window.scrollTop();
      $rootScope.$broadcast('scroll_pos', pos);
      return setTimeout(bindScroll, 100);
    })();
  });

  APP.constant('WEEK_MS', WEEK_MS);

  APP.constant('FINAL_DATE', FINAL_DATE);

  APP.constant('soundcloudConfig', {
    dateFormat: "yyyy-MM-dd HH:mm:ss",
    url: "http://api.soundcloud.com/tracks.json?client_id=ad75c94f50f35a7ee18516d1f04191fd&q={query}&created_at[from]={date_from}&created_at[to]={date_to}"
  });

  APP.constant('tumblrConfig', {
    url: "http://api.tumblr.com/v2/tagged?tag={query}&api_key=eEB0OHd4PI6PocqaxBtwiZRKXs5fqo3aQqoitxmPAKizjDgwl3&before={date_to}&callback=JSON_CALLBACK"
  });

  APP.factory("SoundCloud", function($http, $q, soundcloudConfig, $filter) {
    var SoundCloudPost, dateFormat, filter, get, url;
    SoundCloudPost = (function() {
      function SoundCloudPost(data) {
        this.data = data;
      }

      SoundCloudPost.prototype.type = "soundcloud";

      SoundCloudPost.prototype.url = function() {
        return this.data.permalink_url;
      };

      SoundCloudPost.prototype.photo = function() {
        var _ref;
        return (_ref = this.data.artwork_url) != null ? _ref.replace('-large', '-t500x500') : void 0;
      };

      SoundCloudPost.prototype.caption = function() {
        return this.data.title;
      };

      SoundCloudPost.prototype.date = function() {
        return new Date(this.data.created_at);
      };

      return SoundCloudPost;

    })();
    dateFormat = soundcloudConfig.dateFormat, url = soundcloudConfig.url;
    filter = function(date) {
      return encodeURIComponent($filter('date')(date, dateFormat));
    };
    get = function(query) {
      var date_from, date_to, done, loading, next;
      date_to = Date.now();
      date_from = date_to - WEEK_MS;
      done = false;
      loading = false;
      next = function() {
        var deferred, _url;
        if (done) {
          return {
            done: true
          };
        }
        _url = url.replace('{query}', encodeURIComponent(query)).replace('{date_from}', filter(date_from)).replace('{date_to}', filter(date_to));
        date_to = date_from - 1;
        date_from = date_to - WEEK_MS;
        deferred = $q.defer();
        if (loading) {
          deferred.resolve([]);
        } else {
          loading = true;
          $http.get(_url, {
            cache: true
          }).success(function(data) {
            var posts;
            loading = false;
            posts = data.map(function(track) {
              return new SoundCloudPost(track);
            });
            return deferred.resolve(posts);
          });
        }
        done = date_to < FINAL_DATE;
        return {
          value: deferred.promise,
          done: done
        };
      };
      return {
        next: next
      };
    };
    return {
      get: get
    };
  });

  APP.factory("Tumblr", function($http, $q, tumblrConfig) {
    var TumblrPost, get, url;
    TumblrPost = (function() {
      function TumblrPost(data) {
        this.data = data;
      }

      TumblrPost.prototype.type = "tumblr";

      TumblrPost.prototype.url = function() {
        return this.data.post_url;
      };

      TumblrPost.prototype.photo = function() {
        var _ref, _ref1;
        return (_ref = this.data.photos[0]) != null ? (_ref1 = _ref.alt_sizes[1]) != null ? _ref1.url : void 0 : void 0;
      };

      TumblrPost.prototype.caption = function() {
        return this.data.caption;
      };

      TumblrPost.prototype.date = function() {
        return new Date(this.data.date);
      };

      return TumblrPost;

    })();
    url = tumblrConfig.url;
    get = function(query) {
      var date_from, date_to, done, loading, next;
      date_to = Date.now();
      date_from = date_to - WEEK_MS;
      done = false;
      loading = false;
      next = function() {
        var deferred, _url;
        if (done) {
          return {
            done: true
          };
        }
        _url = url.replace('{query}', encodeURIComponent(query)).replace('{date_to}', Math.floor(date_to / 1000));
        date_to = date_from - 1;
        date_from = date_to - WEEK_MS;
        deferred = $q.defer();
        $http.jsonp(_url, {
          cache: true
        }).success(function(data) {
          var photos, posts, response;
          response = data.response;
          photos = response.filter(function(r) {
            return r.type === "photo" && r.timestamp > date_from / 1000;
          });
          posts = photos.map(function(photo) {
            return new TumblrPost(photo);
          });
          return deferred.resolve(posts);
        });
        done = date_to < FINAL_DATE;
        return {
          value: deferred.promise,
          done: done
        };
      };
      return {
        next: next
      };
    };
    return {
      get: get
    };
  });

  APP.factory("Sources", function(SoundCloud, Tumblr, $q) {
    var get;
    get = function(query) {
      var done, next, sc, tumblr;
      done = false;
      sc = SoundCloud.get(query);
      tumblr = Tumblr.get(query);
      next = function() {
        var deferred, value, _sc, _tumblr;
        if (done) {
          return {
            done: true
          };
        }
        _sc = sc.next();
        _tumblr = tumblr.next();
        done = _sc.done || _tumblr.done;
        deferred = $q.defer();
        $q.all({
          soundcloud: _sc.value,
          tumblr: _tumblr.value
        }).then(function(res) {
          var newResults;
          newResults = [].concat(res.soundcloud, res.tumblr);
          newResults.sort(function(a, b) {
            return b.date() - a.date();
          });
          return deferred.resolve(newResults);
        });
        value = deferred.promise;
        return {
          value: value,
          done: done
        };
      };
      return {
        next: next
      };
    };
    return {
      get: get
    };
  });

  APP.controller("SearchCtrl", function($scope, Sources) {
    return $scope.search = {
      query: "",
      iter: null,
      results: [],
      get: function(valid) {
        if (!valid) {
          return;
        }
        return this.iter = Sources.get(this.query);
      }
    };
  });

  APP.directive("jfInfiniteScroll", function($rootScope, $window) {
    var link, scope, template;
    scope = {
      iter: '=jfInfiniteScroll'
    };
    template = "<ul class=\"inifinite-scroll\">\n  <li class=\"infinite-scroll-element\" ng-repeat=\"result in results\">\n    <div ng-transclude></div>\n  </li>\n</ul>";
    link = function(scope, $el, attrs) {
      var loadUntilFull;
      scope.results = [];
      loadUntilFull = function(e, pos) {
        var result_height, window_height, _ref;
        if (pos == null) {
          pos = 1;
        }
        if (!scope.iter) {
          return;
        }
        window_height = $($window).height();
        result_height = $el.height();
        if (result_height > (window_height * 2) + pos) {
          return;
        }
        return (_ref = scope.iter.next().value) != null ? _ref.then(function(res) {
          scope.results = scope.results.concat(res);
          return setTimeout(loadUntilFull, 100);
        }) : void 0;
      };
      scope.$watch('iter', function(n, p) {
        if (n !== p) {
          scope.results = [];
        }
        return loadUntilFull();
      });
      return $rootScope.$on("scroll_pos", loadUntilFull);
    };
    return {
      scope: scope,
      link: link,
      template: template,
      restrict: 'EA',
      transclude: true,
      replace: true
    };
  });

  APP.directive("jfSourceElement", function() {
    var scope, template;
    scope = {
      el: "=jfSourceElement"
    };
    template = "<a ng-href=\"{{el.url()}}\">\n  <img ng-src=\"{{el.photo()}}\">\n  <div ng-bind-html=\"el.caption()\"></div>\n  <time>{{el.date()|date:'mediumDate'}}</time>\n</a>";
    return {
      scope: scope,
      template: template,
      restrict: 'EA',
      replace: true
    };
  });

}).call(this);
