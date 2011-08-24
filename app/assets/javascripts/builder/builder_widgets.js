var bind = function(func, thisValue, extraArguments, addOriginalThis) {
    var args =  extraArguments || [];
    var add_this = addOriginalThis;
    return function() {
      var _args = (add_this) ? [this]:[];
      
       for(var i = 0 ;i<arguments.length ; i++){
          _args.push(arguments[i]);
        }
        
       for(var j = 0 ;j<args.length ; j++){
          _args.push(args[j]);
        }
       

        return func.apply(thisValue, _args);
    }
}

var dropTargetImage  = $("<img>",{"src":"/assets/drop_target.png", "padding":"0"});



function createItemContainer(image, description){
    var div = $("<div>", {
        "class": "container item"
    });
    var contentRow = $("<div>", {
        "class": "container_row"
    });   
    div.append(contentRow);
    var imageCell = $("<div>", {
        "class": "container_cell builder_image " +image
    });
    var textCell = $("<div>", {
        "class": "container_cell description "
    });
    imageCell.append("&nbsp;");  
    // add the text
    textCell.append(description);
    contentRow.append(imageCell);
    contentRow.append(textCell);
    return div;
}


var factories = {
  "conditions" :function(){  return new queryStructure.And(null,[], "conditions");},
  "observations":function(){ return new queryStructure.And(null,[], "observations"); },
  "treatments":function(){   return new queryStructure.And(null,[], "treatments"); },
  "demographics" : function(){ return new queryStructure.And(null,[], "demographics");},
  "history"      : function(){return new queryStructure.And(null,[], "history"); } 
}

var dropTargetItem = createItemContainer("drop_target", "");

/* Base container UI widget */
$.widget("ui.ContainerUI", {
    options: {

        },
    _create: function() {
        this.container = this.options.container;
        this.parent = this.options.parent;
        this.element.append(this._createContainer());
    }
}

);


/* And container UI widget   


*/
$.widget("ui.AndContainerUI", $.ui.ContainerUI, {
    options: {

        },


    _createContainer: function() {
        var div = $("<div>", {
            "class": "container and"
        });
        this.div = div;
        // this is a table
        var self = this;
        var f = function(i, item) {
            div.append(self._createItemUI(i, item));
        };
        $.each(this.container.children, f);
       
        return div;
    },

    _createItemUI: function(i, item) {
        var row = $("<div>", {
            "class": "container_row and_item"
        });
        // row in the table
        var contentCell = $("<div>", {
            "class": "container_cell"
        });
        
        var dropZoneCell  = $("<div>", {
            "class": "container_cell and_drop_zone"
        });
        dropZoneCell.droppable({
              drop: bind(this.drop, this),
              over: bind(this.over, this),
              out: bind(this.out, this),
              greedy: true
          });
        dropZoneCell.append("&nbsp;") ;
        // second cell in the row ,  content cell
        row.append(contentCell);
        row.append(dropZoneCell);
        if (item && item.name != null) {
            $(contentCell).ItemUI({
                parent: this,
                container: item
            });
        } else {
            if (item instanceof queryStructure.And) {
                $(contentCell).AndContainerUI({
                    parent: this,
                    container: item
                });
            } else {
                $(contentCell).OrContainerUI({
                    parent: this,
                    container: item
                });
            }
        }
        return row;
    },
    drop: function(event,ui) {
      var type = ui.draggable.data("type");
             if(this.container.children.length == 0){
               var or = new queryStructure.Or();
               
               or.add({
                    "type": type,
                    "description": "dropped"
                });
               this.container.add(or);

              var item =  this._createItemUI(-1,or );
               this.div.append(item);
             }else{
               if(this.parent){
                 this.parent.childDropped(this,"right",{
                       "type": type,
                       "description": "dropped"
                   });
               }
             }
             if(this.dropTarget){
                this.dropTarget.remove();
              }
            this.element.css("background-color", "");
    },
    over: function(event,ui) {
        if (this.parent) {
            if (this.dropTarget == null) {
                var cell = $("<div>", {
                    "class": "container_cell"
                });
                // table cell for or row
                var table = $("<div>", {"class": "container"});
                // style row for the cell item
                cell.append(table);
                var styleRow = $("<div>", {"class": "container_row"});
                var contentCell = $("<div>", {"class": "container_row" });
                // content row for the item -- do I need to add a cell to the row to wrap things in?
                table.append(styleRow);
                table.append(contentCell);
                contentCell.append(dropTargetImage);
                this.dropTarget = cell;
            }
            this.element.after(this.dropTarget);
            this.element.css("background-color", "red");
        }
    },
    out: function(event,ui) {
        if (this.dropTarget) {
            this.dropTarget.remove();
            this.element.css("background-color", "");
        }
    },

    childDropped: function(widget, direction, data) {
        if (direction == "bottom") {
            var item = this._createItemUI( - 1, data);
            this.container.add(data,widget.container);
            widget.element.parents(".container_row:first").after(item);
        } else {
            var or = new queryStructure.Or();
            or.add(widget.container);
            or.add(data);
            this.container.replaceChild(widget.container, or);
            var ui = this._createItemUI( - 1, or);
            widget.element.parents(".container_row:first").replaceWith(ui);
        }
    }

}
);

$.widget("ui.OrContainerUI", $.ui.ContainerUI, {
    options: {

        },

    _createContainer: function() {
        var div = $("<div>", {"class": "container or"});
        var row = $("<div>", {"class": "container_row"  });
        div.append(row);
        var self = this;
        var f = function(i, item) {
            row.append(self._createItemUI(i, item));
        };
        $.each(this.container.children, f);

        row.droppable({
            drop: bind(this.drop, this),
            over: bind(this.over, this),
            out: bind(this.out, this),
            greedy: true
        });
        this.div = div;
        this.contentRow = row;
        return div;
    },


    _createItemUI: function(i, item) {
     
        var cell = this._createItemContainer();
        var lineCell = $(".line_style",cell);
        var arr = [cell];
        lineCell.droppable({
             drop: bind(this.childDropped, this,  arr),
             over: bind(this.childOverRight, this, arr),
             out: bind(this.childOutRight, this, arr),
             greedy: true
         });
         
         
        if (item && item.name != null) {
            $(cell).ItemUI({parent: this,container: item});
        } else {
            if (item instanceof queryStructure.And) {
                $(cell).AndContainerUI({
                    parent: this,
                    container: item
                });
            } else {
                $(cell).OrContainerUI({
                    parent: this,
                    container: item
                });
            }
        }
        return cell;
    },

    drop: function(event, ui) {
       var type = ui.draggable.data("type");
       var data = {
           "name": type,
           "description": "dropped"
       };
        if(this.container.children.length == 0){
         
          this.container.add(data);
          
         var item =  this._createItemUI(-1,data);
          this.row.append(item);
        }else{
          this.parent.childDropped(this,"bottom",data);
        }
        if(this.dropTarget){this.dropTarget.remove();}
        this.element.css("background-color", "");
    },
    
    over: function(event,ui) {
        if (this.parent) {
            if (this.dropTarget == null) {
                var row = $("<div>", {
                    "class": "container_row"
                });
                var cell = $("<div></div>");
                row.append(dropTargetImage);
                this.dropTarget = row;
            }
            this.contentRow.after(this.dropTarget);
            this.element.css("background-color", "red");
        }
    },
    
    out: function(event,ui) {
        if (this.dropTarget) {
            this.dropTarget.remove();
            this.element.css("background-color", "");
        }
    },

    childDropped: function(widget, direction, data) {
        if (direction != "bottom") {
            var item = this._createItemUI( -1, data);
            this.container.add(data,widget.container);
            widget.element.after(item);
        } else {
            var and = new queryStructure.And();
            and.add(widget.container);
            and.add(data);
            this.container.replaceChild(widget.container,and);
            var ui = this._createItemUI( - 1, and);
            widget.element.replaceWith(ui);
            
        }
    },
    

    childOverRight: function(event,ui,cell){
      var c =  this.getRightDropTarget();
       c.hide("fast");
       cell.after(c);
       c.show("slow");
    },
    
    childOutRight: function(event,ui,cell){

      this.rightDropTarget.remove();
    },
    getRightDropTarget: function(){
      if(!this.rightDropTarget){
        this.rightDropTarget = this._createItemContainer();
       
        this.rightDropTarget.append(createItemContainer("drop_target",""));
      }
      return this.rightDropTarget;
    },
    
    
    _createItemContainer: function(){
       var cell = $("<div>", {
            "class": "container_cell or_item"
        });
        var style = $("<div>", {"class": "container style_header" });
        var styleRow = $("<div>", {"class": "container_row style_row" });
        var curveCell = $("<div>", {"class": "container_cell curve_style"  });
        var lineCell = $("<div>", {"class": "container_cell line_style" });
        curveCell.append("&nbsp;");
        lineCell.append("&nbsp;");
        style.append(styleRow);
        styleRow.append(curveCell);
        styleRow.append(lineCell);
        cell.append(style);
        return cell;
    }

}

);



$.widget("ui.ItemUI", {
    options: {},

    _init: function() {
        this.container = this.options.container;
        this.parent = this.parent = this.options.parent;
        this.element.append(this._createContainer());
    },

    _createContainer: function() {

        this.div = createItemContainer(this.container.name,this.container.description);
        this.imageCell = $(".builder_image",this.div);
        this.textCell = $(".description",this.div);
        this.contentRow = $(".container_row",this.div);
        // add the appropriate image/component
     //  this.imageCell.append($("<img>", {
      //     "src": "/assets/icon_"+ (this.item.type || 'conditions') +".png"
      // }));

        
        this.imageCell.droppable({
            drop: bind(this._dropBottom,this),
            out: bind(this._outBottom,this),
            accept: bind(this._accept,this),
            over: bind(this._overBottom,this),
            greedy: true
        });

        this.textCell.droppable({
              drop: bind(this._dropRight,this),
              out: bind(this._outRight,this),
              accept: bind(this._accept,this),
              over: bind(this._overRight,this),
              greedy: true
          });

        return this.div;
    },
    _accept: function(event, ui) {
        return true;
    },
    _outRight: function(event, ui) {
       // this.parent.childOut(this,"right",ui);
    },
    _outBottom: function(event, ui) {
        this.contentRow.next().hide("fast");
        this.contentRow.next().remove();
    },
    _dropRight: function(event, ui) {
       
         this.textCell.next().hide("fast");
         this.textCell.next().remove();
        var type = ui.draggable.data("type");
        this.parent.childDropped(this, "right",factories[type]());
    },
    _dropBottom: function(event, ui) {
       
        this.contentRow.next().remove();
       
         var type = ui.draggable.data("type");
         this.parent.childDropped(this, "bottom",factories[type]());
    },
    _overRight: function(event, ui) {
       // this.parent.childOver(this,"right",ui);
        
             //widget.parent.childOver(widget, "right");
             var cell = $("<div>", {
                 "class": "container_cell drop_target"
             });
             // table cell for or row
             cell.append(dropTargetImage);
             cell.hide();
             this.textCell.after(cell);
             cell.show("fast");
    },
    _overBottom: function(event, ui) {
       
        var row = $("<div>", {
            "class": "container_row"
        });
        // row in the table
        var contentCell = $("<div>", {
            "class": "container_cell"
        })
        // second cell in the row ,  content cell
        row.append(contentCell);
        contentCell.append(dropTargetImage);
        row.hide();
        this.div.append(row);
        row.show("fast");

    }
});








