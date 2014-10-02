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

// #### START DIRECTIVES ####
function draggable(scope, element) {
    var elem = element[0];
    elem.draggable = true;

    elem.addEventListener('dragstart', function (e) {
        e.dataTransfer.effectAllowed = 'copy';
        e.dataTransfer.setData('Text', this.id);
        this.classList.add('drag');
        return false;
    },
    false);

    elem.addEventListener('dragend', function (e) {
        this.classList.remove('drag');
        return false;
    }, false);
}

function droppable() {
    return {
        scope: {},
        link: function (scope, element) {
            var elem = element[0];
            
            elem.addEventListener('dragover', function(e) {
                e.dataTransfer.dropEffect = 'copy';
                if(e.preventDefault) e.preventDefault();
                this.classList.add('over');
                return false;
            }, false);
            
            elem.addEventListener('dragenter', function(e) {
                this.classList.add('over');
                return false;
            }, false);
            
            elem.addEventListener('dragleave', function(e) {
                this.classList.remove('over');
                return false;
            }, false);
            
            elem.addEventListener('drop', function(e) {
                if(e.stopPropagation) e.stopPropagation();
                
                this.classList.remove('over');
                var item = document.getElementById(e.dataTransfer.getData('Text'));
                this.appendChild(item);
                
                return false;
            }, false);

        }
    };
}

app.directive('draggable', function () { return draggable; });
app.directive('droppable', droppable);


// #### END DIRECTIVES ####


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
    $scope.successfulAuthentication = function() {

        $scope.api_token = angular.element("#api_token").val();
        console.log("FOUND API TOKEN: "+$scope.api_token);
        
        $scope.nothing = "no text";
        $scope.asdfxxx = "no-lab";

        $scope.form = {};
        $scope.form.labViews = {};

        $scope.course_id = angular.element("#course_id").val();
        console.log("COURSE ID: "+$scope.course_id)

        $scope.createLab = function() {
          console.log("CREATING LAB WITH TITLE: "+$scope.form.labName+ " TEMPLATE: "+$scope.form.templateFolderName+" WITH ID: "+$scope.form.templateID+" AND PARTICIPATION: "+$scope.form.participationModel);

            console.log($scope);
            var data = {
                title: $scope.form.labName,
                folderName: $scope.form.templateFolderName,
                folderId: $scope.form.templateID,
                participation: $scope.form.participationModel,
                course_id: $scope.course_id
            };
            // /lti_google_docs/api/v2/labs/new
            $http.post('/lti_google_docs/api/v2/courses/'+$scope.course_id+'/labs/new', JSON.stringify(data), {headers: {"LTI_API_TOKEN": $scope.api_token}}).success(function(data, status, headers, config) {
                console.log("SUCCESSFUL CREATION!");
                console.log("RETRIEVING NEW LIST OF LABS!");
                $http.get('/lti_google_docs/api/v2/labs', {headers: {"LTI_API_TOKEN": $scope.api_token}})
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
            console.log($scope.itemsToChooseFrom);
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
        //======
        var progressBarModal;
        function ShowProgressBar() {

            var ProgressBarCtrl = function($scope, $modalInstance) {  
            };

            progressBarModal = $modal.open({
                templateUrl: 'ProgressBar.html',
                controller: ProgressBarCtrl
            });

        }

        function hideProgressBar() {
          progressBarModal.close();  
        };
        //======
        $scope.labs = [];

        $scope.itemsToChooseFrom = [];
        $scope.titlesToIDs = {};
        console.log("REQUESTING FILES FROM DRIVE...");
        //silently retrieve list of folders on google drive
        $http({method: 'GET', url: '/lti_google_docs/api/v2/drive_files', headers: {"LTI_API_TOKEN": $scope.api_token}})
            .success(function(data, status, headers, config) {
                console.log("...FILES FROM DRIVE RETRIEVED!");
                for(var i in data) {
                    var file = data[i];

                    if(file.mimeType.indexOf('folder') != -1) {
                        if($scope.itemsToChooseFrom.indexOf(file.title) != -1) {
                            console.log("SKIPPING A DUPLICATE: "+file.title);
                            continue;

                        }
                        $scope.itemsToChooseFrom.push(file.title);
                        $scope.titlesToIDs[file.title] = file.id;
                    }
                }
                console.log($scope.itemsToChooseFrom);
            })
            .error(function(data, status, headers, config) {
                    console.log("ERROR RETRIEVING FILES FROM DRIVE!");
                    console.log(data);
                    console.log(status);

        });

        //retrieve labs
        $http.get('/lti_google_docs/api/v2/labs', {headers: {"LTI_API_TOKEN": $scope.api_token}})
            .success(function(data, status, headers, config) {
                console.log("GOT LABS: ");
                console.log(data);
                $scope.form.labs = data;
            }).error(function(data, status, headers, config) { 
                console.log("ERROR!");
        });

        //retrieve lab instances
        $http.get('/lti_google_docs/api/v2/instances', {headers: {"LTI_API_TOKEN": $scope.api_token}}).success(function(data, status, headers, config) {
            console.log("GOT LAB INSTANCES: ");
            console.log(data);
            $scope.form.labInstances = data;
        }).error(function(data, status, headers, config) {
            console.log("ERROR RETRIEVING LAB INSTANCES");
        });

        
        $http.get('/lti_google_docs/api/v2/courses/'+$scope.course_id+"/students", {headers: {"LTI_API_TOKEN": $scope.api_token}})
            .success(function(data, status, headers, config) {
                console.log("SUCCESSFUL STUDENT RETRIEVAL");
                console.log(data);
                $scope.students = data;
                var number_of_dyads = Math.ceil(data.length/2);
                $scope.groups = [];
                
                for(var i = 0; i < number_of_dyads; i++) {
                    $scope.groups.push({id: (i+1)});
                }
                
                
            })
            .error(function(data, status, headers, config) {
                console.log("ERROR RETRIEVING STUDENTS!");
                console.log(data);
            });
        
        
        
        
        $scope.deleteLab = function(id) {
            console.log("YOU WANT TO DELETE LAB: "+id);
            $http.delete('/lti_google_docs/api/v2/labs/'+id, {headers: {"LTI_API_TOKEN": $scope.api_token}})
            .success(function(data, status, headers, config) {
                console.log("SUCCESS "+data);
                $http.get('/lti_google_docs/api/v2/labs', {headers: {"LTI_API_TOKEN": $scope.api_token}})
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
            $http.delete("/lti_google_docs/api/v2/instances/"+id, {headers: {"LTI_API_TOKEN": $scope.api_token}}).success(function(data, status, headers, config) {
                console.log("SUCCESSFUL DELETION ON SERVER")
                $http.get('/lti_google_docs/api/v2/instances', {headers: {"LTI_API_TOKEN": $scope.api_token}}).success(function(data, status, headers, config) {
                    console.log("GOT LAB INSTANCES: ");
                    console.log(data);
                    $scope.form.labInstances = data;
                }).error(function(data, status, headers, config) {
                    console.log("ERROR RETRIEVING LAB INSTANCES")
                });
            }).error(function(data, status, headers, config) {

            });
        };

        $scope.createLabInstances = function(id) {
            console.log("CREATING INSTANCES FOR LAB: "+id);
            var data = {};
            $http.post('/lti_google_docs/api/v2/labs/'+id+'/instances', JSON.stringify(data), {headers: {"LTI_API_TOKEN": $scope.api_token}})
                .success(function(lab_instances) {
                    console.log("LAB INSTANCES SUCCESSFULLY CREATED!");
                    console.log(lab_instances);
                }).error(function(error) {
                    console.log("ERROR CREATING LAB INSTANCES!");
                    console.log(error);
            });
        };

        $scope.labClick = function(lab) {
            ShowProgressBar();
            $http.get('labs/'+lab.id+'/instances', {headers: {"LTI_API_TOKEN": $scope.api_token}})
                .success(function(data, status, headers, config) {
                    console.log("GOT LAB INSTANCES!");
                    console.log(data);
                    $scope.form.labInstances = data;
                    if(data === "NEEDS AUTHENTICATION!") {
                        window.open('register/canvas', 'LTI_AUTHENTICATION', "width=800, height=600");   
                    }
                    hideProgressBar();
                }).error(function(data, status, headers, config) {
                    console.log("ERROR RETRIEVING LAB INSTANCES");
                    hideProgressBar();
            });

        };

        $scope.removeLabView = function(id) {
            console.log("REMOVING LAB VIEW: "+id);
            delete $scope.form.labViews[id];
        }

    };
    
    $scope.successfulAuthentication();
    //handleLoad($scope);
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

app.controller('RegistrationCtrl', ['$scope', '$http', '$location', function($scope, $http, $location) {

    $scope.form = {};
                    
    $scope.submitRegistration = function() {
        console.log("Submitting registration!");
        console.log($scope.form);
                    
        $http.post('/lti_google_docs/api/v2/clients', $scope.form).success(function(data){
            console.log("SUCCESSFUL POST!");
            console.log(data);
            //$location.path("/lti_google_docs/api/v2/clients/"+data.id);
            location.href="/lti_google_docs/api/v2/clients/"+data.id;
            }).error(function(error) {
                console.log("ERROR POSTING REGISTRATION DATA!");            
        });
    };
}]);

app.controller('AccountInfoCtrl', ['$scope', '$http', '$location', function($scope, $http, $location) {
                    
    console.log(angular.element("#client_id")[0].value);
    var client_id = angular.element("#client_id")[0].value;

                    
    $scope.updateAccountInfo = function() {
        console.log("SENDING UPDATE REQUEST!");
        console.log($scope.form);
                    
        $http.put("/lti_google_docs/api/v2/clients/"+client_id, $scope.form)
                .success(function(data) {
                    console.log("UPDATE RECEIVED");
                    console.log(data);
                    $scope.form = data;
                    })
                .error(function(data) {
                    console.log("ERROR RECEIVED FROM SERVER!");
                    console.log(data);
                    });
    };
    
                    
    $scope.successfulAuthentication = function() {
        console.log("SUCCESSFUL AUTHENTICATION!");
                    
        $http.get("/lti_google_docs/api/v2/clients/"+client_id+"?query=true")
        .success(function(data) {
            console.log("SUCCESSFUL RETRIEVAL!");
            console.log(data);

            $scope.form = data;
            $scope.authenticated = true;
        })
        .error(function(error) {

            console.log("ERROR RETRIEVING ACCOUNT INFORMATION!");
            console.log(error);
        });
                    
    };
    $scope.successfulAuthentication();
    
//    if(handleLoad) {
//        handleLoad($scope);
//    }
}]);
                    
app.controller('CourseInfoCtrl', ['$scope', '$http', function($scope, $http) {
    $scope.courses = [];
    $scope.working = true;
    $http.get("/lti_google_docs/api/v2/courses?list=true")
                    .success(function(courses) {
                        console.log("SUCCESSFUL RETRIEVAL!");
                        console.log(courses);
                        $scope.courses = courses;
                        $scope.working = false;
                    }).error(function(error) {
                        console.log("ERROR IN RETRIEVAL!");
                       console.log(error);
                        $scope.working=false;
                    });
                    

    $scope.refreshModel = function() {
        $scope.working = true;
                    
        $http.get("/lti_google_docs/api/v2/courses?list=true")
                .success(function(courses) {
                    console.log("SUCCESSFUL RETRIEVAL!");
                    console.log(courses);
                    $scope.courses = courses;
                    $scope.working = false;
                }).error(function(error) {
                    console.log("ERROR IN RETRIEVAL!");
                   console.log(error);
                    $scope.working=false;
                });            
    }
                    
    
    $scope.removeCourse = function(id) {
        console.log("DELETING COURSE: "+id);                
        $scope.working = true;
        $http.delete("/lti_google_docs/api/v2/courses/"+id)
            .success(function(data) {
                console.log("SUCCESSFUL DELETION!");
                console.log(data);
                $scope.courses = data;
                    $scope.working = false;
            }).error(function(error){
                console.log("ERROR DELETING ENTRY WITH ID: "+id);
                console.log(error);
                    $scope.working=false;
            });                
    }
}]);
                    
app.controller('ReadyCourseCtrl', ['$scope', function($scope) {
    
    $scope.invalid_canvas_token = true;
    $scope.successfulAuthentication = function() {
      //heyooooo
        console.log("SUCCESSFUL AUTHENTICATION!");
    };
                    
    $scope.requestAuthToken = function() {
        window.open("/lti_google_docs/register/canvas", "LTI Authentication", "width=800, height=600");
    };
}]);
                    
app.controller('LabActivatorCtrl', ['$scope', '$http', function($scope, $http) {
    var lab_id = angular.element("#lti-lab-id").val();
    
    $scope.welcome_message = "LAB FROM HIDDEN INPUT: "+lab_id;
    $scope.api_token = angular.element("#api-token").val();
    console.log("FOUND API TOKEN: "+$scope.api_token);
    // POST TO "/lti_google_docs/api/v2/labs/ lab id /instances"
    
    
    $scope.activateLab = function() {
       var url  = "/lti_google_docs/api/v2/labs/"+lab_id+"/instances"
        var data = {}
        $http.post(url, JSON.stringify(data), {headers: {"LTI_API_TOKEN":$scope.api_token}}).success(function(data) {
            console.log("SUCCESSFUL ACTIVATION!");
            console.log(data);
        }).error(function(error) {
            console.log("ERROR ACTIVATING LAB!");
            console.log(error);
        });
    };
                    
    $scope.deleteAllInstances = function() {
        var url = "/lti_google_docs/api/v2/instances"
        $http.delete(url, {headers: {"LTI_API_TOKEN": $scope.api_token}})
            .success(function(data) {
                console.log("SUCCESS DELETING ALL INSTANCES!");
                console.log(data);
            }).error(function(error) {
                console.log("ERROR DELETING ALL INSTANCES");            
        });
    };
                    
}]);
                    
app.controller('StudentLabCtrl_v2', ['$scope', '$http', '$cookies', function($scope, $http, $cookies) {
    $scope.welcome_message = "This is going to be the death of me --AND YOU TOO!!";
    $scope.paths = [];
    $scope.stuff = [1, 2, 3, 4, 5];
                    
    for(var i in $cookies) {
        console.log(i+"->"+$cookies[i]);                
    }
    var files = angular.fromJson($cookies.shared_files);
    console.log(files);
    $scope.files = files;
    for(var i in files.items) {
        var item = files.items[i];
        console.log(item);
       // var path = "https://docs.google.com/document/d/"+item.id+"/edit?embedded=true";
        var path = "https://docs.google.com/document/d/"+item.id+"/edit";
        console.log(path);
        $scope.paths.push({'title': item.title, 'path': path});
    }
    console.log($scope.paths);
}]);

app.controller('NonStudentLabCtrl', ['$scope', '$http', '$cookies', function($scope, $http, $cookies) {
    
    $scope.welcome_message = "Hello, Designer! Welcome to your lab!";
}]);
                    
app.controller('RetrieveCanvasTokenCtrl', ['$scope', '$window', function($scope, $window) {
    $scope.stuff = [1, 2, 3];
                    
    var canvas_server_address = angular.element("#canvas-server-address").val();
    var canvas_user_id = angular.element("#canvas-user-id").val();
    var consumer_key = angular.element("#consumer-key").val();
    var lti_client_id = angular.element("#lti-client-id").val();
    console.log("FOUND ADDRESS: "+canvas_server_address);
    console.log("FOUND USER ID: "+canvas_user_id);
    console.log("FOUND KEY: "+consumer_key);
    console.log("FOUND ID: "+lti_client_id);
                    
    $scope.showRequestPopup = function() {
        console.log("SHOWING POPUP!");
        $window.open('/lti_google_docs/register/canvas?domain='+canvas_server_address+'&canvas_user_id='+canvas_user_id+'&consumer_key='+consumer_key+"&lti_client_id="+lti_client_id, 'LTI Authentication', "width=800", "height=600");
    };
}]);

app.controller('RequestConfirmedCtrl', ['$scope', function($scope) {

    setTimeout(function() { window.close(); }, 5000);          
    $scope.closeWindow = function() {
        window.close();
    };
}]);
                    
app.controller('RetrieveResourceTokensCtrl', ['$scope', '$window', function($scope, $window) {

    var canvas_server_address = angular.element("#canvas-server-address").val();
    var canvas_user_id = angular.element("#canvas-user-id").val();
    var we_need_google_token = angular.element("#need-google-token").val();
    var we_need_canvas_token = angular.element("#need-canvas-token").val();
    var canvas_clientid = angular.element("#canvas-clientid").val();                
                    
    console.log("FOUND SERVER: "+canvas_server_address);
    console.log("FOUND USER ID: "+canvas_user_id);
    console.log("NEED GOOGLE TOKEN: "+we_need_google_token);
    console.log("NEED CANVAS TOKEN: "+we_need_canvas_token);
    console.log("CANVAS CLIENTID: "+canvas_clientid);
                    
    $scope.showRequestPopup = function() {
                    
        if(we_need_google_token && we_need_canvas_token) {
            var output = $window.open("/lti_google_docs/launch/auth?canvas_server_address="+canvas_server_address+"&canvas_user_id="+canvas_user_id+"&needs_canvas="+we_need_canvas_token+"&canvas_clientid="+canvas_clientid, "LTI Authentication", "with=800, height=600");
            console.log("WINDOW OPENED!");
            console.log(output);    
        } else if(we_need_google_token) {
             var output = $window.open("/lti_google_docs/launch/auth?canvas_server_address="+canvas_server_address+"&canvas_user_id="+canvas_user_id+"&needs_canvas="+we_need_canvas_token+"&canvas_clientid="+canvas_clientid, "LTI Authentication", "with=800, height=600");
            console.log("WINDOW OPENED!");
            console.log(output);       
        } else if(we_need_canvas_token) {
            var output = $window.open('/lti_google_docs/register/canvas?domain='+canvas_server_address+'&canvas_user_id='+canvas_user_id+"&canvas_clientid="+canvas_clientid, 'LTI Authentication', "width=800", "height=600");
            console.log("WINDOW OPENED!");
            console.log(output);
        } else {
             //we don't need either token but the view was loaded?            
        }
    };              
}]);
                    
app.controller('DesignerGroupLabCtrl', ['$scope', '$http', '$cookies', function($scope, $http, $cookies) {
    $scope.groups = [{name: 'Fake Group 1', link: 'https://fake.link.com/?document=woah!', students: [{email: 'woah@dude.com'}]}];
}]);