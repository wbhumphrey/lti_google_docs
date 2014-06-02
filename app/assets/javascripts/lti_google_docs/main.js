var app = angular.module('LTI_GOOGLE_DOCS', []);

app.controller('MainCtrl', function($scope) {
    $scope.items = [];

    $scope.clicky = function() {
        console.log("You clicked the button!");
    };
    
    
    
    //==== GOOGLE DRIVE LOGIC
    var CLIENT_ID = '558678724881-mnbk8edutlbrkvk7tu0v00cpqucp1j15.apps.googleusercontent.com';
    var SCOPES = 'https://www.googleapis.com/auth/drive';
    
    var loadGoogleAPI = function() {
        console.log("CLIENT API LOADED!")
       window.setTimeout(goGoogle, 100); //needed for some strange reason
    };
    
    var goGoogle = function() {
        console.log("GOING GOOGLE!");
        gapi.auth.authorize({'client_id': CLIENT_ID, 'scope': SCOPES, 'immediate': true}, handleResponse);
    }
    
    var handleResponse = function(result) {
        if(!result) {
            console.log("TRYING AGAIN...");
            gapi.auth.authorize({'client_id': CLIENT_ID, 'scope': SCOPES, 'immediate': false}, handleResponse);
        } else {
            console.log("GOOGLE AUTHORIZATION ACQUIRED!");

            //loading API
            var listFilesRequest = gapi.client.load('drive', 'v2', function() {
                
                //building request to list files, only 5 though.
                var req = gapi.client.drive.files.list({'maxResults': 5});
                
                //define recursive function to handle multiple pages of files
                var requestPageOfFiles = function(request, result) {
                    console.log("REQUESTING FILES!");
                    req.execute(function(resp) {
                        result = result.concat(resp.items);
                        var nextPageToken = resp.nextPageTokens;
                        if(nextPageToken) {
                            //drive object is only available here because it is inside load() call above.
                            request = gapi.client.drive.files.list({'pageToken': nextPageToken});
                            requestPageOfFiles(request, result);
                        } else {
                            console.log("SUCCESSFULLY RETRIEVED FILES!");
                            ///because this is likely inside an XHR request and NOT in angularjs,
                            //we need to use $apply
                            $scope.$apply(function() {
                                for(var i in result) {
                                    var res = result[i];
                                    console.log(res.title);
                                    $scope.items.push(res.title);
                                }
                            });
                        }
                    });
                }
                
                //actually call the function that makes the request. 
                // * Remember, this all only ever works because we're inside the gapi.client.load() block. *
                requestPageOfFiles(req, []);
            });

        }
    }
    
    //I was having trouble getting this executed via 'onload=' in the include_javascript_tag,
    //so I explicitly call it here.
    loadGoogleAPI();
});
