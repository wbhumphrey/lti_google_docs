var app = angular.module('LTI_GOOGLE_DOCS', ['ui.bootstrap']);

app.controller('MainCtrl', ['$scope', function($scope) {
    $scope.items = [];

    //will be called from popup window that gapi.auth.authorize() opens.
    var successfulAuthentication = function() {
        
        //start making calls to rails controller
        $scope.$apply(function() { 
            $scope.items.push({'title': 'one'}); 
        });
    };
    window.successfulAuthentication = successfulAuthentication;
}]);
