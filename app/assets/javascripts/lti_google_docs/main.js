var app = angular.module('LTI_GOOGLE_DOCS', []);

app.controller('MainCtrl', function($scope) {
    $scope.items = ["one", "two", "three"];

    $scope.clicky = function() {
        console.log("You clicked the button!");
    };
});
