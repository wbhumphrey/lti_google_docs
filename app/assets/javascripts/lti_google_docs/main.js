var app = angular.module('LTI_GOOGLE_DOCS', ['ngRoute','ui.bootstrap', 'ngCookies']);
app.config(['$routeProvider', '$sceProvider', function($routeProvider, $sceProvider) {
    
    $sceProvider.enabled(false);
    
    $routeProvider
        .when('/',{
            templateUrl: 'main.html',
            controller: 'MainCtrl'
        }).
        when('instances', {
            templateUrl: 'asdf.html',
            controller: 'LabInstancesCtrl'
        }).
        otherwise({
            redirectTo: '/'  
    });
}])



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

app.controller('FactoryCtrl', ['$scope', '$http', '$modal', '$location', function($scope, $http, $modal, $location) {
    
    $scope.nothing = "no text";
    $scope.asdfxxx = "no-lab";
    
    $scope.form = {};
    $scope.form.labViews = {};
    
    $scope.createLab = function() {
      console.log("CREATING LAB WITH TITLE: "+$scope.form.labName+ " TEMPLATE: "+$scope.form.templateFolderName+" WITH ID: "+$scope.form.templateID+" AND PARTICIPATION: "+$scope.form.participationModel);
        
        console.log($scope);
        var data = {
            title: $scope.form.labName,
            folderName: $scope.form.templateFolderName,
            folderId: $scope.form.templateID,
            participation: $scope.form.participationModel
        };
        
        $http.post('labs/new', JSON.stringify(data)).success(function(data, status, headers, config) {
            console.log("SUCCESSFUL CREATION!");
            console.log("RETRIEVING NEW LIST OF LABS!");
            $http.get('labs/all')
                .success(function(data, status, headers, config) {
                    
                    $scope.form.labs = [];
                    $scope.form.labs = data;
                }).error(function(data, status, headers, config) { 
                    console.log("ERROR RE-RETRIEVING LABS!");
            });
            
            
        }).error(function(data, status, headers, config) {
            console.log("ERROR!");
            console.log(data);
            console.log(status);
        });
    };
    
    $scope.selectFolderFromDrive = function() {
      console.log("SELECTING!");  
        
        var FilePickerCtrl = function($scope, $modalInstance, itemsToChooseFrom, titlesToIDs) {
            //defer to rails to retrieve list of files.
            $scope.input = {
                fileid: '',
                title: '',
                selected: ''
            };
            $scope.itemsToChooseFrom = itemsToChooseFrom;
            $scope.titlesToIDs = titlesToIDs;
            
            $scope.ok = function() {
                console.log("USER SELECTED: "+ $scope.input.selected);
                console.log("CORRESPONDING ID: "+$scope.titlesToIDs[$scope.input.selected]);
                $scope.input.id = $scope.titlesToIDs[$scope.input.selected];
                $modalInstance.close($scope.input);
            };
            $scope.selectFolder = function(title) {
                $scope.input.selected = title;
            }
            $scope.cancel = function() {
              $modalInstance.dismiss('cancel');  
            };
        };
        
        var modalInstance = $modal.open({
            templateUrl: 'FileChooser.html',
            controller: FilePickerCtrl,
            resolve: {
                itemsToChooseFrom: function() { return $scope.itemsToChooseFrom; },
                titlesToIDs: function() { return $scope.titlesToIDs; }
            }
        });
        modalInstance.result.then(function (input) {
            //success
            console.log("USER CHOSE: "+input.selected+" WITH ID: "+input.id);
            $scope.form.templateFolderName = input.selected;
            $scope.form.templateID = input.id;
            
        }, function() {
            
            //dismissed
        });
    };
    $scope.labs = [];
    
    $scope.itemsToChooseFrom = [];
    $scope.titlesToIDs = {};
    
    //silently retrieve list of folders on google drive
    $http({method: 'GET', url: 'launch/files'})
        .success(function(data, status, headers, config) {
            console.log("SUCCEEDED!")
            for(var i in data) {
                var file = data[i];

                if(file.mimeType.indexOf('folder') != -1) {
                    $scope.itemsToChooseFrom.push(file.title);
                    $scope.titlesToIDs[file.title] = file.id;
                }
            }
        })
        .error(function(data, status, headers, config) {
                console.log("ERROR!");
                console.log(data);
                console.log(status);
                
    });
    
    //retrieve labs
    $http.get('labs/all')
        .success(function(data, status, headers, config) {
            console.log("GOT LABS: ");
            console.log(data);
            $scope.form.labs = data;
        }).error(function(data, status, headers, config) { 
            console.log("ERROR!");
    });
    
    //retrieve lab instances
    $http.get('labs/instances/all').success(function(data, status, headers, config) {
        console.log("GOT LAB INSTANCES: ");
        console.log(data);
        $scope.form.labInstances = data;
    }).error(function(data, status, headers, config) {
        console.log("ERROR RETRIEVING LAB INSTANCES")
    });
    
    $scope.deleteLab = function(id) {
        console.log("YOU WANT TO DELETE LAB: "+id);
        $http.delete('labs/'+id)
        .success(function(data, status, headers, config) {
            console.log("SUCCESS "+data);
            $http.get('labs/all')
                .success(function(data, status, headers, config) {
                    $scope.form.labs = data;
                    
                }).error(function(data, status, headers, config) {
                    console.log("ERROR RETRIEVING LABS AFTER DELETION");
            });
            
        }).error(function(data, status, headers, config) {
            console.log("ERROR IN DELETE!");
        });
    }
    
    $scope.deleteLabInstance = function(id) {
        console.log("YOU WANT TO DELETE LAB INSTANCE: "+id);
        $http.delete("labs/instances/"+id).success(function(data, status, headers, config) {
            console.log("SUCCESSFUL DELETION ON SERVER")
            $http.get('labs/instances/all').success(function(data, status, headers, config) {
                console.log("GOT LAB INSTANCES: ");
                console.log(data);
                $scope.form.labInstances = data;
            }).error(function(data, status, headers, config) {
                console.log("ERROR RETRIEVING LAB INSTANCES")
            });
        }).error(function(data, status, headers, config) {
            
        });
    };
    
    $scope.labClick = function(lab) {
//        console.log("CLICKED ON TABLE ROW!");
//        console.log(lab);
//        $scope.form.labViews[lab.id] = lab;
        
        $http.get('labs/'+lab.id+'/instances')
            .success(function(data, status, headers, config) {
                console.log("GOT LAB INSTANCES!");
                console.log(data);
                $scope.form.labInstances = data;
                if(data === "NEEDS AUTHENTICATION!") {
                    window.open('register/canvas', 'LTI_AUTHENTICATION', "width=800, height=600");   
                }
                
            }).error(function(data, status, headers, config) {
                console.log("ERROR RETRIEVING LAB INSTANCES");
        });

    };
    
    $scope.removeLabView = function(id) {
        console.log("REMOVING LAB VIEW: "+id);
        delete $scope.form.labViews[id];
    }
    
    $scope.successfulAuthentication = function() {
        console.log("AUTH SUCCESSFUL!");
        
    };
    
    handleLoad($scope);
}]);

var i = app.controller('LabInstancesCtrl', ['$scope', '$http', '$modal', function($scope, $http, $modal) {
    $scope.items = ["a", "b", "c"]
    
}]);

app.controller('StudentLabCtrl', ['$scope', '$http', '$cookies', '$sce', function($scope, $http, $cookies, $sce) {
    $scope.things = ["one", "three", "five", "seven", "nine"];
    $scope.fileIDs = [];
    console.log("PRINTING COOKIES!");
    for(var i in $cookies) {
        console.log(i+"=>"+$cookies[i]);
    }
                    
    var files = angular.fromJson($cookies.files);
    console.log(angular.fromJson(files));
    var file_items = files.items; //is an array
    
    for(var i in file_items) {
        var item = file_items[i];
        console.log("fileid: "+item.id);
//        $sce.trustAsUrl("https://docs.google.com/document/d/"+item.id+"?embedded=true");
        $scope.fileIDs.push({url: "https://docs.google.com/document/d/"+item.id+"", id: item.id});
    }
                    
    
}]);

