var app = angular.module('LTI_GOOGLE_DOCS', ['ui.bootstrap']);

var c = app.controller('MainCtrl', ['$scope', '$http', function($scope, $http) {
    $scope.items = [];
    
    $scope.goCrazy = function() {
        console.log("GOING CRAZY!");  
    };
    
    //will be called from popup window that gapi.auth.authorize() opens.
    $scope.successfulAuthentication = function() {
        
        $http({ method: 'GET', url: 'launch/hello'})
            .success(function(data, status, headers, config) {
                var d = data[0];
                var item = {'title': d.title,
                            'id': d.id,
                            'url': 'https://docs.google.com/document/d/'+d.id+'/pub?embedded=true',
                            'embed': 'https://docs.google.com/document/d/'+d.id+'/edit?embedded=true'};
                $scope.items.push(item);
                
                window.setTimeout(function() {
                    for(var i in $scope.items) {
                        var _item = $scope.items[i];
                        console.log("LOOKING FOR FRAME: frame-"+_item.id);
                        document.getElementById('frame-'+_item.id).src = _item.embed;
                    }
                    
                }, 1000);
                
                console.log("TODO: calling canvas api next");
            }).error(function(data, status, headers, config) {
                console.log("ERROR RETRIEVING FILES FROM DRIVE");
        });
    };
    handleLoad($scope);
}]);
