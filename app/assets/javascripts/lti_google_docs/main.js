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
                console.log(data);
                for(var i in data) {
                    var d = data[i];
                    $scope.items.push({'title': d.title});
                }
                
                console.log("TODO: calling canvas api next");
                $http({method: 'GET', url: "/api/v1/courses/1234/users"})
                    .success(function(data, status, headers, config) {
                        console.log("SUCCESSFUL RETRIEVAL OF USERS FOR COURSE")
                    }).error(function(data, status, headers, config) {
                        console.log(data);
                        console.log(status);
                        console.log("ERROR RETRIEVING USERS FOR COURSE");
                });
            }).error(function(data, status, headers, config) {
                console.log("ERROR RETRIEVING FILES FROM DRIVE");
        });
        
        //start making calls to rails controller
//        $scope.$apply(function() { 
//            $scope.items.push({'title': 'one'}); 
//        });
    };
    handleLoad($scope);
}]);
