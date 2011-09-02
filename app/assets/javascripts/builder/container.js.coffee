@queryStructure = @queryStructure || {}


queryStructure.createContainer= (parent, json) ->
  _ret = null
  _children = []
  if(json["and"])
    _ret =  new queryStructure.And(parent,[])
    _children = json["and"]
  else if(json["or"])
    _ret =   new queryStructure.Or(parent,[])
    _children = json["or"]
  else if(json["not"])
    _ret =   new queryStructure.Not(parent,[])
    _children = json["not"]

  for item in _children
     _ret.add(queryStructure.createContainer(_ret,item))
  
  _ret


class queryStructure.Query
  constructor: ->
    this.find = new queryStructure.And(null)
    this.find.add(new queryStructure.Or())
    this.filter = new queryStructure.And(null)
    this.filter.add(new queryStructure.Or())
    this.extract = new queryStructure.Extraction([], [])

  toJson: -> 
    return { 'find' : this.find.toJson(), 'filter' : this.filter.toJson(), 'extract' : this.extract.toJson() }
  
  rebuildFromJson: (@json) ->
    this.find = this.buildFromJson(null, @json['find'])
    this.filter = this.buildFromJson(null, @json['filter'])
    this.extract = queryStructure.Extraction.rebuildFromJson(@json['extract'])
    
  buildFromJson: (@parent, @element) ->
    if this.getElementType(@element) == 'rule'
      ruleType = this.getRuleType(@element)
      if (ruleType == 'Range')
        return new queryStructure[ruleType](@element['category'], @element['title'], @element['field'], @element['start'], @element['end'])
      else if (ruleType == 'Comparison')
        return new queryStructure[ruleType](@element['category'], @element['title'], @element['field'], @element['value'], @element['comparator'])
      else
        return new queryStructure[ruleType](@element['category'], @element['title'], @element['field'], @element['value'])
    else
      container = this.getContainerType(@element)
      newContainer = new queryStructure[container](@parent, null, @element.name || null)
      for child in @element[container.toLowerCase()]
        newContainer.add(this.buildFromJson(newContainer, child))
      return newContainer
      
  getElementType: (@element) ->
    if @element['and']? || @element['or']? || @element['not']? || @element['count_n']?
      return 'container'
    else
      return 'rule'
          
  getContainerType: (@element) ->
    if @element['and']?
      return 'And'
    else if @element['or']?
      return 'Or'
    else if @element['not']?
      return 'Not'
    else if @element['count_n']?
      return 'CountN'
    else
      return null

  getRuleType: (@element) ->
    if @element['start']?
      return 'Range'
    else if @element['comparator']?
      return 'Comparison'
    else
      return 'Rule'

##############
# Containers 
##############

class queryStructure.Container
  constructor: (@parent, @children = [], @name, @negate = false) ->


  add: (element, after) ->
    # first see if the element is already part of the children array
    # if it is there is no need to do anything
    index = @children.length
    ci = this.childIndex(after)
    if ci != -1
      index = ci + 1
    this.children.splice(index,0,element)
    if element.parent && element.parent != this
      element.parent.removeChild(element)
    element.parent = this
    return element
 
  addAll: (items, after) ->
    for item in items
      after = this.add(item,after)
      
  remove: ->
    if @parent
      @parent.removeChild(this)

  removeChild: (victim) ->
    index = this.childIndex(victim)
    if index != -1
      @children.splice(index,1)
      victim.parent = null
        
  replaceChild: (child, newChild) ->
    index = this.childIndex(child)
    if index != -1
      @children[index] = newChild
      child.parent = null
      newChild.parent = this
  
  moveBefore: (child, other) ->
    i1 = this.childIndex(child)
    i2 = this.childIndex(other)
    if i1 != -1 && i2 != -1
      child = @children.splice(i2, 1)
      @children.splice(i1-1,0,other)
      return true
    
    return false
      
  childIndex: (child) ->
    if child == null
      return -1
    for index, _child of @children
      if _child == child
        return index
    return -1
            
  clear: ->
    children = []

class queryStructure.Or extends queryStructure.Container
  toJson: ->
    childJson = [];
    for child in @children
      childJson.push(child.toJson())
    return { "or" : childJson }
  
  test: (patient) -> 
    if (@children.length == 0)
      return true;
    for child in @children
      if (child.test(patient)) 
        return true;
    return false;


class queryStructure.And extends queryStructure.Container
  toJson: ->
    childJson = [];
    for child in @children
      childJson.push(child.toJson())
    if @name?
      return { "name" : @name, "and" : childJson }
    else
      return { "and" : childJson }

  test: (patient) ->
    for child in @children
      if (!child.test(patient)) 
        return false;
    return true;



class queryStructure.Not extends queryStructure.Container
  toJson: ->
    childJson = [];
    for child in @children
      childJson.push(child.toJson())
    return { "not" : childJson }

    test: (patient) -> 
      for child in @children
        if (child.test(patient)) 
          return true;
      return false;
  

class queryStructure.CountN extends queryStructure.Container
  constructor: (@parent, @n) ->
    super
  
  toJson: ->
    childJson = [];
    for child in @children
      childJson.push(child.toJson())
    return { "n" : this.n, "count_n" : childJson }

    test: (patient) -> 
      for child in @children
        if (child.test(patient)) 
          return true;
      return false;
    

#########
# Rules 
#########
class queryStructure.Rule
  constructor: (@category, @title, @field, @value) ->
  toJson: ->
    return { "category" : @category, "title" : @title, "field" : @field, "value" : @value }
  


class queryStructure.Range
  constructor: (@category, @title, @field, @start, @end) ->
  toJson: ->


class queryStructure.Comparison
  constructor: (@category, @title, @field, @value, @comparator) ->
  toJson: ->
    return { "category" : @category, "title" : @title, "field" : @field, "value" : @value, "comparator" : @comparator }
  test: (patient) ->
    value = null; 
    if (this.field == 'age') 
      value = patient[@field](new Date())
    else 
      value = patient[@field]()
    
    if (@comparator == '=')
      return value == @value
    else if (@comparator == '<')
      return value < @value
    else 
      return value > @value
    

#########
# Fileds 
#########
class queryStructure.Field
  constructor: (@title, @callstack) ->
  toJson: ->
    return { "title" : @title, "callstack" : @callstack }
  extract: (patient) -> 
    # TODO: this needs to be a little more intelligent - AQ
    return patient[callstack]();

class queryStructure.Group extends queryStructure.Field
  constructor: (@title, @callstack) ->
  @rebuildFromJson: (@json) ->
    return new queryStructure.Group(@json['title'], @json['callstack'])

class queryStructure.Selection extends queryStructure.Field
  constructor: (@title, @callstack, @aggregation) ->
  toJson: ->
    return { "title" : @title, "callstack" : @callstack, 'aggregation' : @aggregation }
  @rebuildFromJson: (@json) ->
    return new queryStructure.Selection(@json['title'], @json['callstack'], @json['aggregation'])

class queryStructure.Extraction
  constructor: (@selections, @groups) ->
  toJson: ->
    selectJson = []
    groupJson = []
    for selection in @selections
      selectJson.push(selection.toJson())
    for group in @groups
      groupJson.push(group.toJson())
    return { "selections" : selectJson, "groups" : groupJson }
  @rebuildFromJson: (@json) ->
    selections = []
    groups = []
    for selection in @json['selections']
      selections.push(queryStructure.Selection.rebuildFromJson(selection))
    for group in @json['groups']
      groups.push(queryStructure.Group.rebuildFromJson(group))
    return new queryStructure.Extraction(selections, groups)
