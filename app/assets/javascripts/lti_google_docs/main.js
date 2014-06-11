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

app.controller('FactoryCtrl', ['$scope', '$http', '$modal', function($scope, $http, $modal) {
    
    $scope.nothing = "no text";
    $scope.createLab = function() {
      console.log("CREATING LAB WITH TITLE: "+$scope.labName+ " TEMPLATE: "+$scope.templateFolderName+" WITH ID: "+$scope.templateID+" AND PARTICIPATION: "+$scope.participationModel);
        
        var data = {
            title: $scope.labName,
            folderName: $scope.templateFolderName,
            folderId: $scope.templateID,
            participation: $scope.participationModel
        };
        
        $http.post('labs', JSON.stringify(data)).success(function(data, status, headers, config) {
            console.log("SUCCESSFUL CREATION!");
        }).error(function(data, status, headers, config) {
            console.log("ERROR!");
            console.log(data);
            console.log(status);
        });
    };
    
    $scope.selectFolderFromDrive = function() {
      console.log("SELECTING!");  
        
        var FilePickerCtrl = function($scope, $modalInstance) {
            $scope.itemsToChooseFrom = [];
            $scope.titlesToIDs = {};
            
            $http({method: 'GET', url: 'launch/files'}).success(function(data, status, headers, config) {
                console.log("SUCCEEDED!")
//                console.log(data);
                for(var i in data) {
                    var file = data[i];
//                    console.log(file.title);
//                    console.log(file);
                    if(file.mimeType.indexOf('folder') != -1) {
                        $scope.itemsToChooseFrom.push(file.title);
                        $scope.titlesToIDs[file.title] = file.id;
                    }
                }
                
                
            }).error(function(data, status, headers, config) {
                console.log("ERROR!");
                console.log(data);
                console.log(status);
                
            });
            //defer to rails to retrieve list of files.
            
            $scope.input = {
                fileid: '',
                title: '',
                selected: ''
            };
            
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
            controller: FilePickerCtrl
        });
        modalInstance.result.then(function (input) {
            //success
            console.log("USER CHOSE: "+input.selected+" WITH ID: "+input.id);
            $scope.templateFolderName = input.selected;
            $scope.templateID = input.id;
            
        }, function() {
            
            //dismissed
        });
    };
    
    
}]);
