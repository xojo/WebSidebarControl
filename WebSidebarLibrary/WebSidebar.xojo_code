#tag Class
Protected Class WebSidebar
Inherits WebSDKUIControl
	#tag Event
		Sub DrawControlInLayoutEditor(g As Graphics)
		  g.DrawingColor = TextColor()
		  g.FontSize = 16
		  g.Bold = True
		  Var titleLeft As Integer = 16
		  Var logo As Picture = PictureProperty("logo")
		  If logo <> Nil Then
		    Var logoScale As Double = Min(32.0 / Max(1, logo.Width), 32.0 / Max(1, logo.Height))
		    Var logoWidth As Double = logo.Width * logoScale
		    Var logoHeight As Double = logo.Height * logoScale
		    g.DrawPicture(logo, 16 + (32 - logoWidth) / 2, 16 + (32 - logoHeight) / 2, logoWidth, logoHeight, 0, 0, logo.Width, logo.Height)
		    titleLeft = 60
		  End If
		  g.DrawText(StringProperty("title"), titleLeft, 30, Max(1, g.Width - titleLeft - 12), True)
		  g.Bold = False
		  g.FontSize = 11
		  g.DrawText(StringProperty("subtitle"), titleLeft, 46, Max(1, g.Width - titleLeft - 12), True)
		  g.FontSize = 13
		  
		  // The layout editor compiles this event on its own, so it cannot call the class's methods: the
		  // entry format (see ParseInitialValue) is read inline here.
		  Var inkColor As Color = TextColor()
		  Var mutedColor As Color = Color.RGB(inkColor.Red, inkColor.Green, inkColor.Blue, 140)
		  Var lines() As String = StringProperty("InitialValue").Split(Chr(10))
		  Var y As Integer = 90
		  For Each raw As String In lines
		    Var line As String = raw.Trim
		    If line.IsEmpty Then Continue

		    If line.BeginsWith("#") Then
		      Var heading As String = line.Middle(1).Trim
		      If heading.IsEmpty Then Continue
		      g.Bold = True
		      g.FontSize = 11
		      g.DrawingColor = mutedColor
		      g.DrawText(heading, 16, y, Max(1, g.Width - 28), True)
		      y = y + 30
		    ElseIf line = "---" Then
		      g.DrawingColor = mutedColor
		      g.DrawLine(12, y - 14, g.Width - 12, y - 14)
		      y = y + 10
		    Else
		      Var caption As String = line
		      Var hasIcon As Boolean
		      If line.BeginsWith("<") Then
		        Var closing As Integer = line.IndexOf(">")
		        If closing > 1 And Not line.Middle(closing + 1).Trim.IsEmpty Then
		          hasIcon = True
		          caption = line.Middle(closing + 1).Trim
		        End If
		      End If

		      g.Bold = False
		      g.FontSize = 13
		      Var x As Integer = 16
		      If raw.BeginsWith(" ") Or raw.BeginsWith(Chr(9)) Then x = x + 20
		      If hasIcon Then
		        // A generic circle stands in for any Bootstrap icon.
		        g.DrawingColor = mutedColor
		        g.DrawOval(x, y - 13, 15, 15)
		        x = x + 25
		      End If
		      g.DrawingColor = inkColor
		      g.DrawText(caption, x, y, Max(1, g.Width - x - 12), True)
		      y = y + 36
		    End If
		  Next
		End Sub
	#tag EndEvent

	#tag Event
		Function ExecuteEvent(name As String, parameters As JSONItem) As Boolean
		  If parameters = Nil Then Return False
		  Select Case name
		  Case "CollapsedChanged"
		    If Not Enabled Or Not Visible Then Return True
		    If parameters.Lookup("collapsed", Nil).Type <> Variant.TypeBoolean Then Return True
		    mCollapsed = parameters.Lookup("collapsed", False)
		    UpdateControl
		    RaiseEvent CollapsedChanged(mCollapsed)
		    Return True
		  Case "DrawerChanged"
		    If parameters.Lookup("open", Nil).Type <> Variant.TypeBoolean Then Return True
		    mDrawerOpen = parameters.Lookup("open", False)
		    If Not Enabled Or Not Visible Then mDrawerOpen = False
		    UpdateControl
		    RaiseEvent DrawerChanged(mDrawerOpen)
		    Return True
		  Case "LayoutChanged"
		    If parameters.Lookup("overlay", Nil).Type <> Variant.TypeBoolean Then Return True
		    mOverlay = parameters.Lookup("overlay", False)
		    mLayoutBrowserKnown = True
		    Var reserved As Integer = If(mCollapsed, mCollapsedWidth, mExpandedWidth)
		    If mOverlay Then reserved = 0
		    LayoutContent
		    RaiseEvent LayoutChanged(reserved, mOverlay)
		    Return True
		  Case "GroupExpanded"
		    If Not Enabled Or Not Visible Then Return True
		    If parameters.Lookup("id", Nil).Type <> Variant.TypeString Or parameters.Lookup("expanded", Nil).Type <> Variant.TypeBoolean Then Return True
		    Var groupID As String = parameters.Value("id")
		    Var groupIndex As Integer = FindItem(groupID)
		    If groupIndex >= 0 And HasChildren(groupID) Then
		      Var group As JSONItem = mItems(groupIndex)
		      If Not group.Lookup("disabled", False).BooleanValue And Not group.Lookup("hidden", False).BooleanValue Then SetGroupExpanded(groupID, parameters.Value("expanded").BooleanValue)
		    End If
		    Return True
		  Case "ItemPressed"
		    If Not Enabled Or Not Visible Or parameters = Nil Then Return True
		    If parameters.Lookup("id", Nil).Type <> Variant.TypeString Then Return True
		    Var itemID As String = parameters.Lookup("id", "")
		    Var index As Integer = FindItem(itemID)
		    If index < 0 Then Return True
		    If Not CanSelect(itemID) Or mItems(index).Lookup("url", "").StringValue <> "" Then Return True
		    Var changed As Boolean = mSelectedItemID.Compare(itemID, ComparisonOptions.CaseSensitive) <> 0
		    mSelectedItemID = itemID
		    UpdateControl
		    If changed Then RaiseEvent SelectionChanged(itemID)
		    RaiseEvent ItemPressed(itemID)
		    Return True
		  End Select
		  Return False
		End Function
	#tag EndEvent

	#tag Event
		Function HandleRequest(request As WebRequest, response As WebResponse) As Boolean
		  Return False
		End Function
	#tag EndEvent

	#tag Event
		Function JavaScriptClassName() As String
		  Return "XojoSidebar.Control"
		End Function
	#tag EndEvent

	#tag Event
		Sub Opening()
		  // Capture the expanded design before the browser applies its initial resize.
		  CaptureLayout
		End Sub
	#tag EndEvent

	#tag Event
		Sub Serialize(js As JSONItem)
		  Var items As New JSONItem("[]")
		  For Each item As JSONItem In mItems
		    items.Add(item)
		  Next
		  js.Value("items") = items
		  js.Value("selected") = mSelectedItemID
		  js.Value("title") = mTitle
		  js.Value("subtitle") = mSubtitle
		  // Keep the WebPicture alive for subsequent browser requests.
		  If mLogo <> Nil And mLogoWebPicture = Nil Then mLogoWebPicture = New WebPicture(mLogo)
		  If mLogoWebPicture <> Nil Then
		    js.Value("logo") = mLogoWebPicture.URL
		  Else
		    js.Value("logo") = ""
		  End If
		  js.Value("collapsed") = mCollapsed
		  js.Value("drawerOpen") = mDrawerOpen
		  js.Value("expandedWidth") = mExpandedWidth
		  js.Value("collapsedWidth") = mCollapsedWidth
		  js.Value("breakpoint") = mResponsiveBreakpoint
		  js.Value("theme") = mTheme
		  js.Value("lightAccent") = mLightAccent
		  js.Value("darkAccent") = mDarkAccent
		  js.Value("autoLayout") = AutoLayout
		  js.Value("dropShadow") = mDropShadow
		  If Parent <> Nil Then js.Value("layoutHostID") = Parent.ControlID
		End Sub
	#tag EndEvent

	#tag Event
		Function SessionCSSURLs(session As WebSession) As String()
		  // Styling comes entirely from the Bootstrap stylesheet Xojo already loads.
		  Var urls() As String
		  Return urls
		End Function
	#tag EndEvent

	#tag Event
		Function SessionHead(session As WebSession) As String
		  // Resources are served from embedded constants.
		End Function
	#tag EndEvent

	#tag Event
		Function SessionJavascriptURLs(session As WebSession) As String()
		  If SharedJSFile = Nil Then
		    SharedJSFile = New WebFile
		    // Version token derived from the script content: the filename (and URL) changes
		    // only when the JavaScript changes, so browsers refetch after an update.
		    SharedJSFile.Filename = JSFileName
		    SharedJSFile.MIMEType = "text/javascript"
		    SharedJSFile.Data = kJS
		    SharedJSFile.Session = Nil
		  End If
		  Return Array(SharedJSFile.URL)
		End Function
	#tag EndEvent

	#tag Event
		Sub Shown()
		  mLayoutShown = True
		  LayoutContent
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = 416464732061206E617669676174696F6E206974656D2E205061737320706172656E74494420746F206E65737420697420756E646572206120746F702D6C6576656C206974656D2C206F7220666F6F746572203D205472756520746F2070696E20697420746F2074686520626F74746F6D2E
		Sub AddItem(itemID As String, caption As String, icon As String = "", parentID As String = "", badge As String = "", footer As Boolean = False)
		  ValidateID(itemID)
		  If FindItem(itemID) >= 0 Then Raise New InvalidArgumentException
		  If parentID <> "" Then
		    Var parentIndex As Integer = FindItem(parentID)
		    If parentIndex < 0 Then Raise New InvalidArgumentException
		    If mItems(parentIndex).Lookup("url", "").StringValue <> "" Then Raise New InvalidArgumentException
		    If mItems(parentIndex).Lookup("parent", "").StringValue <> "" Then Raise New InvalidArgumentException
		    If mItems(parentIndex).Lookup("kind", "item").StringValue <> "item" Then Raise New InvalidArgumentException
		    If mSelectedItemID.Compare(parentID, ComparisonOptions.CaseSensitive) = 0 Then mSelectedItemID = ""
		  End If
		  Var item As New JSONItem
		  item.Value("id") = itemID
		  item.Value("caption") = caption
		  item.Value("icon") = icon
		  item.Value("kind") = "item"
		  item.Value("parent") = parentID
		  item.Value("badge") = badge
		  item.Value("footer") = footer
		  item.Value("disabled") = False
		  item.Value("hidden") = False
		  mItems.Add(item)
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 416464732061206E6F6E2D636C69636B61626C652073656374696F6E2068656164696E672E
		Sub AddSection(sectionID As String, caption As String)
		  AddItem(sectionID, caption)
		  mItems(FindItem(sectionID)).Value("kind") = "section"
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 41646473206120686F72697A6F6E74616C2064697669646572206C696E652E
		Sub AddSeparator(separatorID As String)
		  AddItem(separatorID, "")
		  mItems(FindItem(separatorID)).Value("kind") = "separator"
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21, Description = 46696C656E616D6520666F7220746865207363726970742C2077697468206120636F6E74656E74206861736820736F2062726F7773657273207265666574636820697420616674657220616E207570646174652E
		Private Function JSFileName() As String
		  Static name As String
		  If name = "" Then name = "xojo-sidebar-" + EncodeHex(Crypto.MD5(kJS)).Left(8).Lowercase + ".js"
		  Return name
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21, Description = 52657475726E73205472756520696620746865206974656D206578697374732C20697320612076697369626C6520656E61626C6564206C656166206974656D2C20616E642069747320706172656E742069732076697369626C6520616E6420656E61626C65642E
		Private Function CanSelect(itemID As String) As Boolean
		  Var index As Integer = FindItem(itemID)
		  If index < 0 Then Return False
		  Var item As JSONItem = mItems(index)
		  If item.Lookup("kind", "item").StringValue <> "item" Then Return False
		  If item.Lookup("disabled", False).BooleanValue Or item.Lookup("hidden", False).BooleanValue Then Return False
		  Var parentID As String = item.Lookup("parent", "")
		  If parentID <> "" Then
		    Var parentIndex As Integer = FindItem(parentID)
		    If parentIndex < 0 Then Return False
		    If mItems(parentIndex).Lookup("hidden", False).BooleanValue Or mItems(parentIndex).Lookup("disabled", False).BooleanValue Then Return False
		  End If
		  For Each candidate As JSONItem In mItems
		    If candidate.Lookup("parent", "").StringValue.Compare(itemID, ComparisonOptions.CaseSensitive) = 0 Then Return False
		  Next
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub CaptureLayout()
		  If Not AutoLayout Or Parent = Nil Or mLayoutContext <> Nil Then Return
		  // Alternating sidebars use one baseline, even if another instance is hidden.
		  For Each candidate As WebControl In Parent.Controls
		    If candidate IsA WebSidebar And candidate <> Self Then
		      Var sidebar As WebSidebar = WebSidebar(candidate)
		      If sidebar.Parent = Parent And sidebar.mLayoutContext <> Nil Then
		        mLayoutContext = sidebar.mLayoutContext
		        Return
		      End If
		    End If
		  Next
		  mLayoutContext = New Dictionary
		  mLayoutContext.Value("width") = Parent.Width
		  mLayoutContext.Value("height") = Parent.Height
		  mLayoutContext.Value("reserved") = Left + Width
		  Var bounds As New Dictionary
		  For Each candidate As WebControl In Parent.Controls
		    If Not (candidate IsA WebUIControl) Or candidate IsA WebSidebar Then Continue
		    Var control As WebUIControl = WebUIControl(candidate)
		    If control.Parent <> Parent Then Continue
		    Var original As New Dictionary
		    original.Value("left") = control.Left
		    original.Value("top") = control.Top
		    original.Value("width") = control.Width
		    original.Value("height") = control.Height
		    original.Value("lockLeft") = control.LockLeft
		    original.Value("lockRight") = control.LockRight
		    original.Value("lockTop") = control.LockTop
		    original.Value("lockBottom") = control.LockBottom
		    original.Value("lockHorizontal") = control.LockHorizontal
		    original.Value("lockVertical") = control.LockVertical
		    bounds.Value(control.ControlID) = original
		  Next
		  mLayoutContext.Value("bounds") = bounds
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 52656D6F76657320616C6C206974656D7320616E6420636C65617273207468652073656C656374696F6E2E
		Sub Clear()
		  mItems.RemoveAll
		  mItemPictures = Nil
		  mSelectedItemID = ""
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 436C6F73657320746865206D6F62696C65206E617669676174696F6E206472617765722E
		Sub CloseDrawer()
		  mDrawerOpen = False
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 52657475726E73205472756520696620616E206974656D20776974682074686973204944206578697374732E
		Function ContainsItem(itemID As String) As Boolean
		  Return FindItem(itemID) >= 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21, Description = 52657475726E732074686520696E646578206F6620746865206974656D207769746820746869732049442028636173652D73656E736974697665292C206F72202D31206966206E6F7420666F756E642E
		Private Function FindItem(itemID As String) As Integer
		  For i As Integer = 0 To mItems.LastIndex
		    If mItems(i).Value("id").StringValue.Compare(itemID, ComparisonOptions.CaseSensitive) = 0 Then Return i
		  Next
		  Return -1
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function HasChildren(itemID As String) As Boolean
		  For Each candidate As JSONItem In mItems
		    If candidate.Lookup("parent", "").StringValue.Compare(itemID, ComparisonOptions.CaseSensitive) = 0 Then Return True
		  Next
		  Return False
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub LayoutContent()
		  If Not AutoLayout Or Not mLayoutShown Or Not Visible Or Parent = Nil Then Return
		  CaptureLayout
		  If mLayoutContext = Nil Then Return
		  // One visible sidebar per parent. A hidden instance never changes content.
		  // Use the framework's dimensions so its native anchors share our coordinate space.
		  Var hostWidth As Integer = Parent.Width
		  Var hostHeight As Integer = Parent.Height
		  Var overlay As Boolean = If(mLayoutBrowserKnown, mOverlay, Page.Width < ResponsiveBreakpoint)
		  Var reservedWidth As Integer = If(Collapsed, CollapsedWidth, ExpandedWidth)
		  Var reservedHeight As Integer
		  If overlay Then
		    reservedWidth = 0
		    reservedHeight = 60
		  End If
		  Left = 0
		  Top = 0
		  Width = If(overlay, hostWidth, reservedWidth)
		  Height = If(overlay, reservedHeight, hostHeight)
		  Var designReserved As Integer = mLayoutContext.Value("reserved")
		  Var designWidth As Integer = mLayoutContext.Value("width")
		  Var designHeight As Integer = mLayoutContext.Value("height")
		  Var contentWidth As Integer = Max(1, hostWidth - reservedWidth)
		  Var contentHeight As Integer = Max(1, hostHeight - reservedHeight)
		  Var widthChange As Integer = contentWidth - (designWidth - designReserved)
		  Var heightChange As Integer = contentHeight - designHeight
		  Var bounds As Dictionary = mLayoutContext.Value("bounds")
		  For Each candidate As WebControl In Parent.Controls
		    If Not (candidate IsA WebUIControl) Or candidate IsA WebSidebar Then Continue
		    Var control As WebUIControl = WebUIControl(candidate)
		    If control.Parent <> Parent Or Not bounds.HasKey(control.ControlID) Then Continue
		    Var original As Dictionary = bounds.Value(control.ControlID)
		    Var originalLeft As Integer = original.Value("left")
		    Var originalTop As Integer = original.Value("top")
		    Var newWidth As Integer = original.Value("width")
		    Var newHeight As Integer = original.Value("height")
		    Var newLeft As Integer = originalLeft - designReserved + reservedWidth
		    Var newTop As Integer = originalTop + reservedHeight
		    If original.Value("lockHorizontal").BooleanValue Then
		      Var centerRatio As Double = (originalLeft - designReserved + newWidth / 2.0) / Max(1, designWidth - designReserved)
		      newLeft = reservedWidth + Round(centerRatio * contentWidth - newWidth / 2.0)
		    ElseIf original.Value("lockRight").BooleanValue Then
		      If original.Value("lockLeft").BooleanValue Then
		        newWidth = Max(1, newWidth + widthChange)
		      Else
		        newLeft = newLeft + widthChange
		      End If
		    End If
		    If original.Value("lockVertical").BooleanValue Then
		      Var centerRatio As Double = (originalTop + newHeight / 2.0) / Max(1, designHeight)
		      newTop = reservedHeight + Round(centerRatio * contentHeight - newHeight / 2.0)
		    ElseIf original.Value("lockBottom").BooleanValue Then
		      If original.Value("lockTop").BooleanValue Then
		        newHeight = Max(1, newHeight + heightChange)
		      Else
		        newTop = newTop + heightChange
		      End If
		    End If
		    // Recompute from the baseline; native resizing cannot compound our offsets.
		    control.Left = newLeft
		    control.Top = newTop
		    control.Width = newWidth
		    control.Height = newHeight
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21, Description = 436C65617273207468652073656C656374696F6E206966207468652073656C6563746564206974656D2063616E206E6F206C6F6E6765722062652073656C65637465642E
		Private Sub NormalizeSelection()
		  If mSelectedItemID <> "" And Not CanSelect(mSelectedItemID) Then
		    mSelectedItemID = ""
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4F70656E7320746865206E617669676174696F6E20647261776572207768656E20746865207369646562617220697320696E206D6F62696C65206C61796F75742E
		Sub OpenDrawer()
		  mDrawerOpen = True
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 52656D6F76657320746865206974656D207769746820746869732049442C20616C6F6E67207769746820697473206368696C64206974656D732E
		Sub RemoveItem(itemID As String)
		  For i As Integer = mItems.LastIndex DownTo 0
		    If mItems(i).Value("id").StringValue.Compare(itemID, ComparisonOptions.CaseSensitive) = 0 Or mItems(i).Lookup("parent", "").StringValue.Compare(itemID, ComparisonOptions.CaseSensitive) = 0 Then
		      If mItemPictures <> Nil And mItemPictures.HasKey(mItems(i)) Then mItemPictures.Remove(mItems(i))
		      mItems.RemoveAt(i)
		    End If
		  Next
		  NormalizeSelection
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function RequireItem(itemID As String) As JSONItem
		  Var index As Integer = FindItem(itemID)
		  If index < 0 Then Raise New InvalidArgumentException
		  Return mItems(index)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 486967686C696768747320746865206974656D206173207468652063757272656E7420706167652E205061737320616E20656D70747920737472696E6720746F20636C656172207468652073656C656374696F6E2E
		Sub SelectItem(itemID As String)
		  If itemID <> "" And Not CanSelect(itemID) Then Raise New InvalidArgumentException
		  If itemID <> "" And mSelectedItemID.Compare(itemID, ComparisonOptions.CaseSensitive) <> 0 Then
		    Var item As JSONItem = RequireItem(itemID)
		    Var parentID As String = item.Lookup("parent", "")
		    If parentID <> "" Then mItems(FindItem(parentID)).Value("expanded") = True
		  End If
		  mSelectedItemID = itemID
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 536574732074686520626164676520746578742073686F776E20616674657220616E206974656D27732063617074696F6E2E205061737320616E20656D70747920737472696E6720746F20686964652069742E
		Sub SetBadge(itemID As String, value As String)
		  Var index As Integer = FindItem(itemID)
		  If index < 0 Then Raise New InvalidArgumentException
		  mItems(index).Value("badge") = value
		  NormalizeSelection
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4368616E676573207468652063617074696F6E206F6620616E206578697374696E67206974656D2E
		Sub SetCaption(itemID As String, value As String)
		  Var index As Integer = FindItem(itemID)
		  If index < 0 Then Raise New InvalidArgumentException
		  mItems(index).Value("caption") = value
		  NormalizeSelection
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetGroupExpanded(itemID As String, expanded As Boolean)
		  Var item As JSONItem = RequireItem(itemID)
		  If Not HasChildren(itemID) Then Raise New InvalidArgumentException
		  item.Value("expanded") = expanded
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4368616E67657320616E206974656D27732069636F6E2028686F6D652C20666F6C6465722C2063686172742C2075736572732C2073657474696E67732C2068656C702C20696E626F782C2067726964292E
		Sub SetIcon(itemID As String, value As String)
		  Var index As Integer = FindItem(itemID)
		  If index < 0 Then Raise New InvalidArgumentException
		  Var item As JSONItem = mItems(index)
		  If mItemPictures <> Nil And mItemPictures.HasKey(item) Then mItemPictures.Remove(item)
		  item.Value("pictureURL") = ""
		  item.Value("icon") = value
		  NormalizeSelection
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetItemCSSClasses(itemID As String, classes As String)
		  Var item As JSONItem = RequireItem(itemID)
		  item.Value("cssClasses") = classes.Trim
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 456E61626C6573206F722064697361626C657320616E206974656D2E20412064697361626C6564206974656D2063616E27742062652070726573736564206F722073656C65637465642E
		Sub SetItemEnabled(itemID As String, value As Boolean)
		  Var index As Integer = FindItem(itemID)
		  If index < 0 Then Raise New InvalidArgumentException
		  mItems(index).Value("disabled") = Not value
		  NormalizeSelection
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetItemPicture(itemID As String, picture As Picture)
		  Var item As JSONItem = RequireItem(itemID)
		  If item.Value("kind").StringValue <> "item" Then Raise New InvalidArgumentException
		  If picture = Nil Then
		    If mItemPictures <> Nil And mItemPictures.HasKey(item) Then mItemPictures.Remove(item)
		    item.Value("pictureURL") = ""
		  Else
		    If mItemPictures = Nil Then mItemPictures = New Dictionary
		    Var resource As New WebPicture(picture)
		    mItemPictures.Value(item) = resource
		    item.Value("pictureURL") = resource.URL
		  End If
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub SetItemURL(itemID As String, url As String)
		  Var item As JSONItem = RequireItem(itemID)
		  If item.Value("kind").StringValue <> "item" Or HasChildren(itemID) Then Raise New InvalidArgumentException
		  If url <> "" Then
		    Var invalid As New RegEx
		    invalid.SearchPattern = "[\x00-\x20\x7F\\\\]"
		    If invalid.Search(url) <> Nil Then Raise New InvalidArgumentException
		    Var scheme As New RegEx
		    scheme.SearchPattern = "^[A-Za-z][A-Za-z0-9+.\-]*:"
		    If scheme.Search(url) <> Nil And Not (url.BeginsWith("https://") Or url.BeginsWith("http://")) Then Raise New InvalidArgumentException
		  End If
		  item.Value("url") = url
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 53686F7773206F7220686964657320616E206974656D20776974686F75742072656D6F76696E672069742E
		Sub SetItemVisible(itemID As String, value As Boolean)
		  Var index As Integer = FindItem(itemID)
		  If index < 0 Then Raise New InvalidArgumentException
		  mItems(index).Value("hidden") = Not value
		  NormalizeSelection
		  UpdateControl
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 5377697463686573206265747765656E20657870616E64656420616E6420636F6C6C6170736564202869636F6E73206F6E6C7929206D6F64652E
		Sub ToggleCollapsed()
		  Collapsed = Not Collapsed
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21, Description = 52616973657320496E76616C6964417267756D656E74457863657074696F6E20756E6C657373207468652076616C756520697320656D707479206F72206120235252474742422068657820636F6C6F722E
		Private Sub ValidateColor(value As String)
		  If value = "" Then Return
		  If value.Length <> 7 Or value.Left(1) <> "#" Then Raise New InvalidArgumentException
		  Const digits As String = "0123456789abcdefABCDEF"
		  For i As Integer = 1 To 6
		    If digits.IndexOf(value.Middle(i, 1)) < 0 Then Raise New InvalidArgumentException
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21, Description = 52616973657320496E76616C6964417267756D656E74457863657074696F6E20756E6C6573732074686520494420697320312D3830206368617261637465727320776974686F757420636F6E74726F6C20636861726163746572732E
		Private Sub ValidateID(itemID As String)
		  If itemID.IsEmpty Or itemID.Length > 80 Then Raise New InvalidArgumentException
		  // Any visible text is allowed, so an entry's caption can be its own ID. Control characters are not.
		  For i As Integer = 0 To itemID.Length - 1
		    If Asc(itemID.Middle(i, 1)) < 32 Then Raise New InvalidArgumentException
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub LoadInitialValue()
		  // Rebuilds every item from InitialValue. Each entry's ID is its caption.
		  Clear
		  Var kinds() As String
		  Var captions() As String
		  Var icons() As String
		  Var levels() As Integer
		  ParseInitialValue(mInitialValue, kinds, captions, icons, levels)

		  Var parentID As String
		  Var separatorCount As Integer
		  For i As Integer = 0 To kinds.LastIndex
		    Select Case kinds(i)
		    Case "section"
		      AddSection("#" + captions(i), captions(i))
		      parentID = ""
		    Case "separator"
		      separatorCount = separatorCount + 1
		      AddSeparator("---" + Str(separatorCount))
		      parentID = ""
		    Else
		      Var caption As String = captions(i)
		      If caption.Length > 80 Or ContainsItem(caption) Then
		        Var problem As New InvalidArgumentException
		        problem.Message = "InitialValue entry is too long or repeated: " + caption
		        Raise problem
		      End If
		      If levels(i) > 0 And Not parentID.IsEmpty Then
		        AddItem(caption, caption, icons(i), parentID)
		      Else
		        AddItem(caption, caption, icons(i))
		        parentID = caption
		      End If
		    End Select
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h121
		Private Shared Sub ParseInitialValue(text As String, kinds() As String, captions() As String, icons() As String, levels() As Integer)
		  // One entry per line:
		  //   #Heading            a section heading
		  //   ---                 a separator
		  //   <bi-house> Overview an item with a Bootstrap icon (the icon is optional)
		  //   (indented)          a child of the item above
		  Var lines() As String = text.ReplaceLineEndings(Chr(10)).Split(Chr(10))
		  For Each raw As String In lines
		    Var line As String = raw.Trim
		    If line.IsEmpty Then Continue

		    Var kind As String = "item"
		    Var caption As String = line
		    Var icon As String
		    Var level As Integer
		    If line.BeginsWith("#") Then
		      kind = "section"
		      caption = line.Middle(1).Trim
		      If caption.IsEmpty Then Continue
		    ElseIf line = "---" Then
		      kind = "separator"
		      caption = ""
		    Else
		      If raw.BeginsWith(" ") Or raw.BeginsWith(Chr(9)) Then level = 1
		      If line.BeginsWith("<") Then
		        Var closing As Integer = line.IndexOf(">")
		        If closing > 1 Then
		          icon = line.Middle(1, closing - 1).Trim
		          caption = line.Middle(closing + 1).Trim
		          If caption.IsEmpty Then
		            // Nothing follows the icon: the whole line is the caption.
		            icon = ""
		            caption = line
		          End If
		        End If
		      End If
		    End If

		    kinds.Add(kind)
		    captions.Add(caption)
		    icons.Add(icon)
		    levels.Add(level)
		  Next
		End Sub
	#tag EndMethod


	#tag Hook, Flags = &h0, Description = 526169736564207768656E20746865207573657220657870616E6473206F7220636F6C6C61707365732074686520736964656261722E
		Event CollapsedChanged(collapsed As Boolean)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 526169736564207768656E20746865206D6F62696C6520647261776572206F70656E73206F7220636C6F7365732E
		Event DrawerChanged(open As Boolean)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 526169736564207768656E20746865207573657220707265737365732061206E617669676174696F6E206974656D2E
		Event ItemPressed(itemID As String)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 526169736564207768656E2074686520736964656261722773207769647468206F72206C61796F7574206D6F6465206368616E6765732E2072657365727665645769647468206973207468652073706163652069742074616B657320757020283020696E206F7665726C6179206D6F6465293B2075736520697420746F207265706F736974696F6E207061676520636F6E74656E742E
		Event LayoutChanged(reservedWidth As Integer, overlay As Boolean)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 526169736564207768656E207468652073656C6563746564206974656D206368616E6765732E
		Event SelectionChanged(itemID As String)
	#tag EndHook


	#tag Property, Flags = &h0
		AutoLayout As Boolean = True
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 4472617773206120737562746C6520736861646F7720616C6F6E67207468652073696465626172206564676520746F2073657061726174652069742066726F6D20746865207061676520636F6E74656E742E
		#tag Getter
			Get
			  Return mDropShadow
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If mDropShadow = value Then Return
			  mDropShadow = value
			  UpdateControl
			End Set
		#tag EndSetter
		DropShadow As Boolean
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 547275652073686F77732074686520636F6D706163742C2069636F6E732D6F6E6C7920736964656261722E
		#tag Getter
			Get
			  Return mCollapsed
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If mCollapsed = value Then Return
			  mCollapsed = value
			  LayoutContent
			  UpdateControl
			End Set
		#tag EndSetter
		Collapsed As Boolean
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 576964746820696E20706978656C73207768656E20636F6C6C61707365642028363420746F20457870616E6465645769647468292E
		#tag Getter
			Get
			  Return mCollapsedWidth
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mCollapsedWidth = Max(64, Min(value, mExpandedWidth))
			  LayoutContent
			  UpdateControl
			End Set
		#tag EndSetter
		CollapsedWidth As Integer
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 416363656E7420636F6C6F7220282352524747424229207573656420696E206461726B206D6F64652E204C6561766520656D70747920746F2075736520746865207468656D652773207072696D61727920636F6C6F722E
		#tag Getter
			Get
			  Return mDarkAccent
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  ValidateColor(value)
			  mDarkAccent = value
			  UpdateControl
			End Set
		#tag EndSetter
		DarkAccent As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 576964746820696E20706978656C73207768656E20657870616E64656420286D696E696D756D20313630292E
		#tag Getter
			Get
			  Return mExpandedWidth
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mExpandedWidth = Max(160, value)
			  mCollapsedWidth = Min(mCollapsedWidth, mExpandedWidth)
			  LayoutContent
			  UpdateControl
			End Set
		#tag EndSetter
		ExpandedWidth As Integer
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return mInitialValue
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If mInitialValue = value Then
			    Return
			  End If
			  
			  mInitialValue = value
			  LoadInitialValue
			End Set
		#tag EndSetter
		InitialValue As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 546F74616C206E756D626572206F6620656E74726965732C20696E636C7564696E672073656374696F6E7320616E6420736570617261746F72732E
		#tag Getter
			Get
			  Return mItems.Count
			End Get
		#tag EndGetter
		ItemCount As Integer
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 416363656E7420636F6C6F7220282352524747424229207573656420696E206C69676874206D6F64652E204C6561766520656D70747920746F2075736520746865207468656D652773207072696D61727920636F6C6F722E
		#tag Getter
			Get
			  Return mLightAccent
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  ValidateColor(value)
			  mLightAccent = value
			  UpdateControl
			End Set
		#tag EndSetter
		LightAccent As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  Return mLogo
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mLogo = value
			  mLogoWebPicture = Nil
			  UpdateControl
			End Set
		#tag EndSetter
		Logo As Picture
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private mDropShadow As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F7220436F6C6C61707365642E
		Private mCollapsed As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F7220436F6C6C617073656457696474682E
		Private mCollapsedWidth As Integer = 72
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F72204461726B416363656E742E
		Private mDarkAccent As String = ""
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 54727565207768696C6520746865206D6F62696C6520647261776572206973206F70656E2E
		Private mDrawerOpen As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F7220457870616E64656457696474682E
		Private mExpandedWidth As Integer = 256
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mInitialValue As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mItemPictures As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4974656D20646566696E6974696F6E732073656E7420746F207468652062726F777365722C20696E20646973706C6179206F726465722E
		Private mItems() As JSONItem
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLayoutBrowserKnown As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLayoutContext As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLayoutShown As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F72204C69676874416363656E742E
		Private mLightAccent As String = ""
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogo As Picture
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLogoWebPicture As WebPicture
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 54727565207768656E207468652062726F77736572207265706F72747320746865206D6F62696C6520286F7665726C617929206C61796F75742E
		Private mOverlay As Boolean = False
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F7220526573706F6E73697665427265616B706F696E742E
		Private mResponsiveBreakpoint As Integer = 768
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F722053656C65637465644974656D49442E
		Private mSelectedItemID As String = ""
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F72205375627469746C652E
		Private mSubtitle As String = ""
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F72205468656D652E
		Private mTheme As String = "auto"
	#tag EndProperty

	#tag Property, Flags = &h21, Description = 4261636B696E67206669656C6420666F72205469746C652E
		Private mTitle As String = "Workspace"
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 42656C6F77207468697320706167652077696474682028696E20706978656C732C206D696E696D756D2033323029207468652073696465626172206265636F6D65732061206D656E7520627574746F6E2074686174206F70656E732061206472617765722E
		#tag Getter
			Get
			  Return mResponsiveBreakpoint
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mResponsiveBreakpoint = Max(320, value)
			  LayoutContent
			  UpdateControl
			End Set
		#tag EndSetter
		ResponsiveBreakpoint As Integer
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 4944206F6620746865206974656D20686967686C696768746564206173207468652063757272656E7420706167652C206F7220656D70747920666F72206E6F6E652E
		#tag Getter
			Get
			  Return mSelectedItemID
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  SelectItem(value)
			End Set
		#tag EndSetter
		SelectedItemID As String
	#tag EndComputedProperty

	#tag Property, Flags = &h21, Description = 5368617265642057656246696C652074686174207365727665732074686520736964656261722773204A61766153637269707420746F2065766572792073657373696F6E2E
		Private Shared SharedJSFile As WebFile
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 536D616C6C6572206C696E65206F6620746578742073686F776E20756E64657220746865207469746C652E
		#tag Getter
			Get
			  Return mSubtitle
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If mSubtitle.Compare(value, ComparisonOptions.CaseSensitive) = 0 Then Return
			  mSubtitle = value
			  UpdateControl
			End Set
		#tag EndSetter
		Subtitle As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 436F6C6F7220736368656D653A20226175746F222028666F6C6C6F77207468652070616765292C20226C6967687422206F7220226461726B222E
		#tag Getter
			Get
			  Return mTheme
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If value = "" Then value = "auto"
			  If value <> "auto" And value <> "light" And value <> "dark" Then Raise New InvalidArgumentException
			  mTheme = value.Lowercase
			  UpdateControl
			End Set
		#tag EndSetter
		Theme As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 576F726B7370616365206E616D652073686F776E20696E20746865206865616465722E20497473206669727374206C6574746572206973207573656420617320746865206D6F6E6F6772616D2E
		#tag Getter
			Get
			  Return mTitle
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  If mTitle.Compare(value, ComparisonOptions.CaseSensitive) = 0 Then Return
			  mTitle = value
			  UpdateControl
			End Set
		#tag EndSetter
		Title As String
	#tag EndComputedProperty


	#tag Constant, Name = kJS, Type = String, Dynamic = False, Default = \"var XojoSidebar;\n(function (ns) {\n    const paths \x3D {\n        home:\'m3 10 9-7 9 7v10h-6v-7H9v7H3z\'\x2C folder:\'M3 7V4h6l2 3h10v13H3z\'\x2C\n        chart:\'M4 3v17h17M8 15v-4m5 4V7m5 8V4\'\x2C\n        users:\'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2m20 0v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0\'\x2C\n        settings:\'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8M9 3h6l1 3 3 1 2 5-2 5-3 1-1 3H9l-1-3-3-1-2-5 2-5 3-1z\'\x2C\n        help:\'M9 9a3 3 0 1 1 5 2c-2 1-2 2-2 3m0 3h.01M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0\'\x2C\n        inbox:\'M3 3h18v18H3zM3 13h5l2 3h4l2-3h5\'\x2C grid:\'M3 3h7v7H3zm11 0h7v7h-7zM3 14h7v7H3zm11 0h7v7h-7z\'\x2C\n        chevron:\'m9 6 6 6-6 6\'\x2C chevrondown:\'m6 9 6 6 6-6\'\x2C menu:\'M4 6h16M4 12h16M4 18h16\'\x2C\n        collapse:\'m11 17-5-5 5-5m7 10-5-5 5-5\'\x2C expand:\'m13 17 5-5-5-5M6 17l5-5-5-5\'\x2C\n        close:\'m6 6 12 12M6 18 18 6\'\x2C dot:\'M8 12h8\'\n    };\n    function icon(name) {\n        const ns\x3D\'http://www.w3.org/2000/svg\'\x2C svg\x3Ddocument.createElementNS(ns\x2C\'svg\');\n        // Presentation attributes keep the icon self-contained: no stylesheet is needed.\n        const attrs\x3D{viewBox:\'0 0 24 24\'\x2Cwidth:\'1.25em\'\x2Cheight:\'1.25em\'\x2Cfill:\'none\'\x2Cstroke:\'currentColor\'\x2C\'stroke-width\':\'1.6\'\x2C\n            \'stroke-linecap\':\'round\'\x2C\'stroke-linejoin\':\'round\'\x2C\'class\':\'flex-shrink-0\'\x2C\'aria-hidden\':\'true\'\x2Cfocusable:\'false\'};\n        Object.keys(attrs).forEach(key\x3D>svg.setAttribute(key\x2Cattrs[key]));\n        if (!name) return svg;\n        const path\x3Ddocument.createElementNS(ns\x2C\'path\');\n        path.setAttribute(\'d\'\x2Cpaths[name] || paths.dot); svg.appendChild(path); return svg;\n    }\n    function element(tag\x2Ccls\x2Ctext) {\n        const el\x3Ddocument.createElement(tag); if(cls) el.className\x3Dcls;\n        if(text!\x3D\x3Dundefined) el.textContent\x3Dtext; return el;\n    }\n    class Control extends XojoWeb.XojoVisualControl {\n        constructor(id\x2Cevents) {\n            super(id\x2Cevents);\n            this.config\x3D{items:[]\x2Ctitle:\'Workspace\'\x2Csubtitle:\'\'\x2Clogo:\'\'\x2Cselected:\'\'\x2Ccollapsed:false\x2CdrawerOpen:false\x2C\n                expandedWidth:256\x2CcollapsedWidth:72\x2Cbreakpoint:768\x2Ctheme:\'auto\'};\n            this.layoutKey\x3D\'\'; this.closed\x3Dfalse; this.tips\x3D[]; this.menus\x3D[]; this.fades\x3D[]; this.accentOn\x3Dfalse;\n            this.themeObserver\x3Dnew MutationObserver(()\x3D>{const before\x3Dthis.accentOn; this.syncTheme(); if(before!\x3D\x3Dthis.accentOn) this.refresh();});\n            this.themeObserver.observe(document.documentElement\x2C{attributes:true\x2Csubtree:true\x2CattributeFilter:[\'data-bs-theme\']});\n        }\n        updateControl(data) {\n            super.updateControl(data);\n            Object.assign(this.config\x2CJSON.parse(data));\n            if(this.mediaBreakpoint!\x3D\x3Dthis.config.breakpoint) {\n                if(this.media) this.media.removeEventListener(\'change\'\x2Cthis.onMedia);\n                this.mediaBreakpoint\x3Dthis.config.breakpoint;\n                this.media\x3Dwindow.matchMedia(\'(max-width: \'+(this.config.breakpoint-1)+\'px)\');\n                this.onMedia\x3D()\x3D>{\n                    if(!this.media.matches) this.setDrawer(false\x2Ctrue);\n                    this.refresh(); this.notifyLayout();\n                };\n                this.media.addEventListener(\'change\'\x2Cthis.onMedia);\n            }\n            this.refresh(); this.observeLayoutHost(); this.notifyLayout();\n        }\n        observeLayoutHost() {\n            const el\x3Dthis.DOMElement();\n            const host\x3Dthis.config.autoLayout && el \? document.getElementById(this.config.layoutHostID) || el.parentElement : null;\n            if(host\x3D\x3D\x3Dthis.layoutHost) return;\n            if(this.layoutObserver)this.layoutObserver.disconnect();\n            this.layoutHost\x3Dhost; this.layoutKey\x3D\'\';\n            if(host) {\n                this.layoutObserver\x3Dnew ResizeObserver(()\x3D>this.notifyLayout());\n                this.layoutObserver.observe(host);\n            }\n        }\n        notifyLayout() {\n            if(!this.media || this.closed || !this.physicallyVisible) return;\n            const overlay\x3Dthis.media.matches;\n            const width\x3Doverlay \? 0 : (this.config.collapsed \? this.config.collapsedWidth : this.config.expandedWidth);\n            const hostWidth\x3Dthis.layoutHost \? this.layoutHost.clientWidth : 0;\n            const hostHeight\x3Dthis.layoutHost \? this.layoutHost.clientHeight : 0;\n            const key\x3Dwidth+\':\'+overlay+\':\'+hostWidth+\':\'+hostHeight;\n            if(key\x3D\x3D\x3Dthis.layoutKey) return;\n            this.layoutKey\x3Dkey; this.send(\'LayoutChanged\'\x2C{width:width\x2Coverlay:overlay\x2ChostWidth:hostWidth\x2ChostHeight:hostHeight});\n        }\n        send(name\x2Cvalues) {\n            if(this.closed) return;\n            const params\x3Dnew XojoWeb.JSONItem();\n            Object.keys(values).forEach(key\x3D>params.set(key\x2Cvalues[key]));\n            this.triggerServerEvent(name\x2Cparams\x2Ctrue);\n        }\n        initialize(el) {\n            if(this.panel) return;\n            this.panel\x3Delement(\'div\'\x2C\'xs-panel d-flex flex-column h-100 bg-body text-body\');\n            this.launcher\x3Delement(\'button\'\x2C\'xs-launcher btn btn-outline-secondary m-2 d-none\'); this.launcher.type\x3D\'button\';\n            this.launcher.dataset.key\x3D\'launcher\'; this.launcher.setAttribute(\'aria-label\'\x2C\'Open navigation\');\n            this.launcher.setAttribute(\'aria-haspopup\'\x2C\'dialog\'); this.launcher.appendChild(icon(\'menu\'));\n            this.launcher.onclick\x3D()\x3D>this.setDrawer(true\x2Ctrue);\n            // The mobile drawer is a Bootstrap offcanvas: backdrop\x2C focus trap\x2C Escape and transitions come with it.\n            this.drawer\x3Delement(\'div\'\x2C\'xs-drawer offcanvas offcanvas-start\'); this.drawer.id\x3Dthis.controlID(\'_drawer\');\n            this.drawer.tabIndex\x3D-1; this.drawer.setAttribute(\'aria-label\'\x2C\'Main navigation\');\n            this.drawer.style.setProperty(\'--bs-offcanvas-width\'\x2C\'288px\');\n            this.drawerBody\x3Delement(\'div\'\x2C\'offcanvas-body d-flex flex-column p-0 overflow-hidden\');\n            this.drawer.appendChild(this.drawerBody);\n            this.launcher.setAttribute(\'aria-controls\'\x2Cthis.drawer.id);\n            this.drawer.addEventListener(\'hidden.bs.offcanvas\'\x2C()\x3D>{\n                this.launcher.setAttribute(\'aria-expanded\'\x2C\'false\');\n                if(this.config.drawerOpen && !this.closed) {this.config.drawerOpen\x3Dfalse; this.send(\'DrawerChanged\'\x2C{open:false});}\n                if(this.returnFocus && this.returnFocus.isConnected && this.physicallyVisible) this.returnFocus.focus();\n                this.returnFocus\x3Dnull;\n            });\n            el.append(this.panel\x2Cthis.launcher\x2Cthis.drawer);\n            // Created after attaching: the offcanvas backdrop is rooted in the element\'s parent.\n            this.offcanvas\x3Dnew bootstrap.Offcanvas(this.drawer);\n        }\n        setDrawer(open\x2Cnotify) {\n            if(open && (!this.enabled || !this.physicallyVisible || !this.media || !this.media.matches)) return;\n            const changed\x3Dthis.config.drawerOpen!\x3D\x3Dopen;\n            this.config.drawerOpen\x3Dopen; this.syncDrawer();\n            if(changed && notify) this.send(\'DrawerChanged\'\x2C{open:open});\n        }\n        syncDrawer() {\n            if(!this.drawer) return;\n            const open\x3D!!(this.config.drawerOpen && this.media && this.media.matches && this.enabled && this.physicallyVisible);\n            this.launcher.setAttribute(\'aria-expanded\'\x2CString(open));\n            const shown\x3Dthis.drawer.classList.contains(\'show\');\n            if(open && !shown) {this.returnFocus\x3Ddocument.activeElement; this.offcanvas.show();}\n            else if(!open && shown) this.offcanvas.hide();\n        }\n        // A pill list. With an accent set\x2C the selected pill uses it (Bootstrap\'s own pill variables).\n        navList(extra) {\n            const list\x3Delement(\'ul\'\x2C\'nav nav-pills flex-column flex-nowrap\'+(extra \? \' \'+extra : \'\'));\n            if(this.accentOn) this.applyAccent(list\x2C\'--bs-nav-pills-link-active\');\n            return list;\n        }\n        applyAccent(node\x2Cprefix) {\n            node.style.setProperty(prefix+\'-bg\'\x2C\'var(--xs-accent)\');\n            node.style.setProperty(prefix+\'-color\'\x2C\'var(--xs-accent-ink)\');\n        }\n        // Labels that appear when the rail changes state fade in with Bootstrap\'s .fade/.show.\n        fadeable(node) {\n            if(this.swapping) {node.classList.add(\'fade\'); this.fades.push(node);}\n            return node;\n        }\n        render() {\n            super.render(); const el\x3Dthis.DOMElement(); if(!el || !this.media) return;\n            this.setAttributes(); el.classList.add(\'xojo-sidebar\'\x2C\'overflow-hidden\'); el.dataset.theme\x3Dthis.config.theme;\n            this.syncTheme();\n            this.initialize(el);\n            const mobile\x3Dthis.media.matches\x2C compact\x3D!mobile && this.config.collapsed;\n            el.classList.toggle(\'xs-mobile\'\x2Cmobile); el.classList.toggle(\'xs-compact\'\x2Ccompact);\n            // Bootstrap\'s shadow utility marks the edge between the sidebar and the page. z-1 keeps it above neighbouring content.\n            const shadow\x3D!!this.config.dropShadow && !mobile;\n            el.classList.toggle(\'shadow\'\x2Cshadow); el.classList.toggle(\'z-1\'\x2Cshadow);\n            this.swapping\x3Dthis.wasCompact!\x3D\x3Dundefined && this.wasCompact!\x3D\x3Dcompact; this.wasCompact\x3Dcompact; this.fades\x3D[];\n            this.launcher.classList.toggle(\'d-none\'\x2C!mobile); this.launcher.disabled\x3D!this.enabled;\n            // Only our own panel moves. Framework-managed sibling controls stay untouched.\n            if(mobile && this.panel.parentElement!\x3D\x3Dthis.drawerBody) this.drawerBody.appendChild(this.panel);\n            if(!mobile && this.panel.parentElement!\x3D\x3Del) el.insertBefore(this.panel\x2Cthis.launcher);\n            // Tooltips and flyouts belong to the previous render.\n            this.tips.forEach(t\x3D>t.dispose()); this.tips\x3D[]; this.menus.forEach(m\x3D>m.dispose()); this.menus\x3D[];\n            const active\x3Dthis.panel.contains(document.activeElement) \? document.activeElement.dataset.key : null;\n            const oldNav\x3Dthis.panel.querySelector(\'.xs-nav\')\x2C scrollTop\x3DoldNav \? oldNav.scrollTop : 0;\n            const header\x3Delement(\'header\'\x2C\'xs-header d-flex align-items-center gap-2 p-2 flex-shrink-0 \'+(compact \? \'justify-content-center\' : \'justify-content-between\'));\n            const brand\x3Delement(\'div\'\x2C\'xs-brand d-flex align-items-center gap-2 overflow-hidden\');\n            if(this.config.logo) {\n                const logo\x3Delement(\'img\'\x2C\'xs-logo flex-shrink-0 object-fit-contain\'); logo.src\x3Dthis.config.logo; logo.alt\x3D\'\';\n                logo.width\x3D32; logo.height\x3D32; brand.appendChild(logo);\n            } else {\n                brand.appendChild(element(\'span\'\x2C\'xs-monogram badge rounded-2 text-bg-secondary fs-6 flex-shrink-0\'\x2Cthis.config.title.slice(0\x2C1).toUpperCase()));\n            }\n            if(!compact) {\n                const names\x3Dthis.fadeable(element(\'div\'\x2C\'xs-brand-text d-flex flex-column overflow-hidden\'));\n                names.append(element(\'strong\'\x2C\'text-truncate\'\x2Cthis.config.title)\x2Celement(\'small\'\x2C\'text-truncate text-body-secondary\'\x2Cthis.config.subtitle)); brand.appendChild(names);\n            }\n            header.appendChild(brand);\n            const label\x3Dmobile \? \'Close navigation\' : compact \? \'Expand navigation\' : \'Collapse navigation\';\n            let toggle;\n            if(mobile) {\n                toggle\x3Delement(\'button\'\x2C\'xs-toggle btn-close\');\n                toggle.onclick\x3D()\x3D>this.setDrawer(false\x2Ctrue);\n                header.appendChild(toggle);\n            } else {\n                // Desktop: a nav-link in its own bar below the footer\x2C so it matches the items above it.\n                toggle\x3Delement(\'button\'\x2C\'xs-toggle nav-link d-flex align-items-center gap-2 w-100 text-start\'+(compact \? \' justify-content-center\' : \'\'));\n                toggle.appendChild(icon(compact \? \'expand\' : \'collapse\'));\n                if(!compact) toggle.appendChild(this.fadeable(element(\'span\'\x2C\'xs-toggle-label\'\x2C\'Collapse\')));\n                toggle.onclick\x3D()\x3D>{\n                    this.config.collapsed\x3D!this.config.collapsed; this.refresh();\n                    this.send(\'CollapsedChanged\'\x2C{collapsed:this.config.collapsed}); this.notifyLayout();\n                };\n                if(compact) this.tips.push(new bootstrap.Tooltip(toggle\x2C{placement:\'right\'\x2Ctrigger:\'hover\'\x2Ccontainer:\'body\'\x2Ctitle:label}));\n            }\n            toggle.type\x3D\'button\'; toggle.dataset.key\x3D\'toggle\';\n            toggle.setAttribute(\'aria-label\'\x2Clabel); toggle.disabled\x3D!this.enabled;\n            const nav\x3Delement(\'nav\'\x2C\'xs-nav flex-grow-1 overflow-auto p-2\'); nav.setAttribute(\'aria-label\'\x2C\'Main navigation\');\n            nav.addEventListener(\'keydown\'\x2Ce\x3D>this.navigationKey(e\x2Cnav));\n            const footer\x3Delement(\'nav\'\x2C\'xs-footer p-2 flex-shrink-0\'); footer.setAttribute(\'aria-label\'\x2C\'Secondary navigation\');\n            footer.addEventListener(\'keydown\'\x2Ce\x3D>this.navigationKey(e\x2Cfooter));\n            const list\x3Dthis.navList(\'xs-list\')\x2C footList\x3Dthis.navList(\'xs-list\');\n            this.config.items.filter(item\x3D>!item.parent && !item.hidden).forEach(item\x3D>{\n                (item.footer \? footList : list).appendChild(this.renderItem(item\x2Ccompact));\n            });\n            // The first heading sits flush with the top of the list.\n            const firstSection\x3Dlist.querySelector(\':scope > li:first-child > .xs-section\'); if(firstSection) firstSection.classList.replace(\'pt-3\'\x2C\'pt-0\');\n            nav.appendChild(list); footer.appendChild(footList); footer.hidden\x3D!footList.children.length;\n            const parts\x3D[header\x2Cnav\x2Cfooter];\n            if(!mobile) {\n                const bar\x3Delement(\'div\'\x2C\'xs-toolbar border-top p-2 flex-shrink-0\')\x2C barList\x3Dthis.navList()\x2C barItem\x3Delement(\'li\'\x2C\'nav-item\');\n                barItem.appendChild(toggle); barList.appendChild(barItem); bar.appendChild(barList); parts.push(bar);\n            }\n            this.panel.replaceChildren(...parts); nav.scrollTop\x3DscrollTop;\n            if(this.swapping) requestAnimationFrame(()\x3D>requestAnimationFrame(()\x3D>this.fades.forEach(n\x3D>n.classList.add(\'show\'))));\n            if(active) {\n                const restored\x3DArray.from(this.panel.querySelectorAll(\'[data-key]\')).find(n\x3D>n.dataset.key\x3D\x3D\x3Dactive);\n                if(restored && !restored.disabled) restored.focus({preventScroll:true}); else toggle.focus({preventScroll:true});\n            }\n            this.applyTooltip(el); this.applyUserStyle(); this.syncDrawer();\n        }\n        // Icon\x2C caption and badge. The rail drops the caption and pins the badge to the corner (Bootstrap\'s positioned-badge pattern).\n        itemContent(button\x2Citem\x2Ccompact) {\n            if(item.pictureURL) {\n                const image\x3Delement(\'img\'\x2C\'xs-item-picture flex-shrink-0 object-fit-contain\');\n                image.src\x3Ditem.pictureURL; image.alt\x3D\'\'; image.width\x3D20; image.height\x3D20; button.appendChild(image);\n            } else if(/^bi-[a-z0-9-]+$/.test(item.icon)) {\n                const glyph\x3Delement(\'i\'\x2C\'bi flex-shrink-0 \'+item.icon);\n                glyph.setAttribute(\'aria-hidden\'\x2C\'true\'); button.appendChild(glyph);\n            } else if(item.icon) button.appendChild(icon(item.icon));\n            else if(compact) button.appendChild(element(\'span\'\x2C\'\'\x2CArray.from(item.caption)[0] || \'\'));\n            if(!compact) button.appendChild(this.fadeable(element(\'span\'\x2C\'xs-caption flex-grow-1 text-break\'\x2Citem.caption)));\n            if(item.badge) {\n                const badge\x3Delement(\'span\'\x2C\'xs-badge badge text-bg-secondary\'+(compact \? \' rounded-pill position-absolute top-0 end-0 mt-1 me-1\' : \'\')\x2Citem.badge);\n                badge.setAttribute(\'aria-hidden\'\x2C\'true\'); button.appendChild(this.fadeable(badge));\n            }\n        }\n        itemLabel(item) {return item.caption+(item.badge \? \'\x2C \'+item.badge : \'\');}\n        // A leaf inside a rail flyout: a Bootstrap dropdown item.\n        menuItem(item\x2CparentDisabled) {\n            const li\x3Delement(\'li\'\x2C\'xs-entry\');\n            const disabled\x3D!this.enabled || item.disabled || !!parentDisabled;\n            const link\x3D!!item.url && !disabled;\n            const button\x3Delement(link \? \'a\' : \'button\'\x2C\'xs-item dropdown-item d-flex align-items-center gap-2\'+(item.cssClasses \? \' \'+item.cssClasses : \'\'));\n            if(link) button.href\x3Ditem.url; else {button.type\x3D\'button\'; button.disabled\x3Ddisabled;}\n            button.dataset.key\x3D\'item:\'+item.id; button.dataset.item\x3Ditem.id;\n            button.setAttribute(\'aria-label\'\x2Cthis.itemLabel(item));\n            this.itemContent(button\x2Citem\x2Cfalse);\n            if(item.id\x3D\x3D\x3Dthis.config.selected) {button.classList.add(\'active\'); button.setAttribute(\'aria-current\'\x2C\'page\');}\n            if(!link) button.onclick\x3D()\x3D>{if(!this.enabled || item.disabled) return;this.send(\'ItemPressed\'\x2C{id:item.id});};\n            li.appendChild(button); return li;\n        }\n        renderItem(item\x2Ccompact\x2CparentDisabled) {\n            const li\x3Delement(\'li\'\x2C\'xs-entry nav-item\');\n            const classes\x3Ditem.cssClasses \? \' \'+item.cssClasses : \'\';\n            if(item.kind\x3D\x3D\x3D\'section\') {\n                if(compact) li.appendChild(element(\'hr\'\x2C\'xs-section my-2 mx-2\'+classes));\n                else li.appendChild(element(\'span\'\x2C\'xs-section d-block small fw-semibold text-body-secondary px-3 pt-3 pb-1\'+classes\x2Citem.caption));\n                return li;\n            }\n            if(item.kind\x3D\x3D\x3D\'separator\') {li.appendChild(element(\'hr\'\x2C\'xs-separator\'+classes));return li;}\n            const children\x3Dthis.config.items.filter(child\x3D>child.parent\x3D\x3D\x3Ditem.id && !child.hidden);\n            const hasChildren\x3Dthis.config.items.some(child\x3D>child.parent\x3D\x3D\x3Ditem.id);\n            const disabled\x3D!this.enabled || item.disabled || !!parentDisabled;\n            const link\x3D!!item.url && !hasChildren && !disabled;\n            const button\x3Delement(link \? \'a\' : \'button\'\x2C\'xs-item nav-link d-flex align-items-center gap-2 w-100 text-start\'+(compact \? \' position-relative justify-content-center\' : \'\')+classes);\n            if(link) button.href\x3Ditem.url;\n            else { button.type\x3D\'button\'; button.disabled\x3Ddisabled; }\n            button.dataset.key\x3D\'item:\'+item.id;\n            button.dataset.item\x3Ditem.id;\n            button.setAttribute(\'aria-label\'\x2Cthis.itemLabel(item));\n            this.itemContent(button\x2Citem\x2Ccompact);\n            if(compact) {\n                // Bootstrap allows one component per element: a group\'s tooltip goes on its list item\x2C next to the dropdown.\n                const tip\x3Dnew bootstrap.Tooltip(hasChildren \? li : button\x2C{placement:\'right\'\x2Ctrigger:\'hover\'\x2Ccontainer:\'body\'\x2Ctitle:item.caption+(item.badge \? \' (\'+item.badge+\')\' : \'\')});\n                this.tips.push(tip); li.addEventListener(\'show.bs.dropdown\'\x2C()\x3D>tip.hide());\n            }\n            if(!hasChildren && item.id\x3D\x3D\x3Dthis.config.selected) {\n                button.classList.add(\'active\');\n                button.setAttribute(\'aria-current\'\x2C\'page\');\n            }\n            if(hasChildren && compact) {\n                // The rail keeps its width: children open in a Bootstrap dropdown to the right.\n                li.classList.add(\'dropend\');\n                const menu\x3Delement(\'ul\'\x2C\'xs-children dropdown-menu\');\n                if(this.accentOn) this.applyAccent(menu\x2C\'--bs-dropdown-link-active\');\n                children.forEach(child\x3D>menu.appendChild(this.menuItem(child\x2Cbutton.disabled)));\n                button.setAttribute(\'data-bs-toggle\'\x2C\'dropdown\'); button.setAttribute(\'aria-haspopup\'\x2C\'true\'); button.setAttribute(\'aria-expanded\'\x2C\'false\');\n                if(children.some(child\x3D>child.id\x3D\x3D\x3Dthis.config.selected)) button.classList.add(\'active\');\n                li.append(button\x2Cmenu);\n                // Attached first: the dropdown looks for its menu next to the button. A fixed strategy lets it escape the scrolling area.\n                this.menus.push(new bootstrap.Dropdown(button\x2C{popperConfig:cfg\x3D>Object.assign({}\x2Ccfg\x2C{strategy:\'fixed\'})}));\n            } else if(hasChildren) {\n                const group\x3Dthis.navList(\'xs-children ps-3\');group.id\x3Dthis.controlID(\'_group_\'+this.config.items.indexOf(item));\n                group.hidden\x3D!item.expanded;\n                button.setAttribute(\'aria-expanded\'\x2CString(!group.hidden));button.setAttribute(\'aria-controls\'\x2Cgroup.id);\n                button.appendChild(icon(item.expanded \? \'chevrondown\' : \'chevron\'));\n                children.forEach(child\x3D>group.appendChild(this.renderItem(child\x2Cfalse\x2Cbutton.disabled)));\n                button.onclick\x3D()\x3D>{\n                    item.expanded\x3D!item.expanded;\n                    this.send(\'GroupExpanded\'\x2C{id:item.id\x2Cexpanded:item.expanded});\n                    this.refresh();\n                };li.append(button\x2Cgroup);\n            } else {\n                if(link) {\n                    button.onclick\x3De\x3D>{if(this.media.matches && !e.ctrlKey && !e.metaKey && !e.shiftKey && !e.altKey)this.setDrawer(false\x2Ctrue);};\n                } else button.onclick\x3D()\x3D>{if(!this.enabled || item.disabled) return;this.send(\'ItemPressed\'\x2C{id:item.id});if(this.media.matches)this.setDrawer(false\x2Ctrue);};\n                li.appendChild(button);\n            } return li;\n        }\n        navigationKey(e\x2Cnav) {\n            // Flyout items use the dropdown\'s own keyboard handling.\n            const buttons\x3DArray.from(nav.querySelectorAll(\'button:not(:disabled)\x2C a[href]\')).filter(b\x3D>!b.closest(\'[hidden]\x2C .dropdown-menu\'));\n            const current\x3Dbuttons.indexOf(document.activeElement);let next\x3Dcurrent;\n            if(current<0) return;\n            if(e.key\x3D\x3D\x3D\'ArrowDown\')next\x3D(current+1)%buttons.length;\n            else if(e.key\x3D\x3D\x3D\'ArrowUp\')next\x3D(current-1+buttons.length)%buttons.length;\n            else if(e.key\x3D\x3D\x3D\'Home\')next\x3D0;else if(e.key\x3D\x3D\x3D\'End\')next\x3Dbuttons.length-1;else return;\n            if(buttons[next]){e.preventDefault();buttons[next].focus();}\n        }\n        syncTheme() {\n            const el\x3Dthis.DOMElement();if(!el || this.closed)return;\n            if(this.config.theme\x3D\x3D\x3D\'auto\')el.removeAttribute(\'data-bs-theme\');\n            else if(el.getAttribute(\'data-bs-theme\')!\x3D\x3Dthis.config.theme)el.setAttribute(\'data-bs-theme\'\x2Cthis.config.theme);\n            const owner\x3Del.closest(\'[data-bs-theme]\');\n            const dark\x3Downer && owner.getAttribute(\'data-bs-theme\')\x3D\x3D\x3D\'dark\';\n            const accent\x3Ddark \? this.config.darkAccent : this.config.lightAccent;\n            el.toggleAttribute(\'data-xs-accent\'\x2C!!accent);\n            this.accentOn\x3D!!accent;\n            if(!accent) {\n                el.style.removeProperty(\'--xs-accent\');\n                el.style.removeProperty(\'--xs-accent-ink\');\n                return;\n            }\n            // Select the higher-contrast black or white foreground.\n            const channels\x3Daccent.slice(1).match(/../g).map(pair\x3D>{\n                const value\x3DparseInt(pair\x2C16)/255;\n                return value<\x3D0.04045 \? value/12.92 : ((value+0.055)/1.055)**2.4;\n            });\n            const luminance\x3D0.2126*channels[0]+0.7152*channels[1]+0.0722*channels[2];\n            el.style.setProperty(\'--xs-accent\'\x2Caccent);\n            el.style.setProperty(\'--xs-accent-ink\'\x2Cluminance>0.179 \? \'#000\' : \'#fff\');\n        }\n        setVisible(value) {if(!value)this.setDrawer(false\x2Ctrue);super.setVisible(value);if(value){this.layoutKey\x3D\'\';this.notifyLayout();}}\n        close() {\n            this.closed\x3Dtrue;if(this.media)this.media.removeEventListener(\'change\'\x2Cthis.onMedia);\n            this.themeObserver.disconnect();\n            if(this.layoutObserver)this.layoutObserver.disconnect();this.layoutHost\x3Dnull;\n            this.tips.forEach(t\x3D>t.dispose()); this.menus.forEach(m\x3D>m.dispose());\n            if(this.offcanvas) {if(this.drawer.classList.contains(\'show\')) this.offcanvas.hide(); this.offcanvas.dispose();}\n            this.returnFocus\x3Dnull;super.close();\n        }\n    }\n    ns.Control\x3DControl;\n})(XojoSidebar || (XojoSidebar \x3D {}));\n", Scope = Private, Description = 436C69656E742D73696465204A61766153637269707420666F7220746865207369646562617220636F6E74726F6C2E
	#tag EndConstant

	#tag Constant, Name = LibraryIcon, Type = String, Dynamic = False, Default = \"iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAEmElEQVR42s2XS4hbVRjH//9z7r3JnUwmmT5oSwvSOi5a8AFSsVh8ILhwoavoRhR1IRanINVWRXvnVkptfRTLKOhCwS60E8WVuBFX3Si0OwuCWmWwU/qYSeaRx32cz0VupjNJmmTqFD0QyM3NOd//fN/v+853gP94sPPPwq6zBJDrT+5iidL9T54oFETfrN16nqc8z1OdPeCJgk8DAHfsk4xU4JRR7rjQQ87nkkepf8v5PPKwI99/ab4pxPd9c02ACEHKyNN/3crU8GFKvFsQu2IE7BCO+/NfWln7KmKxeoZBIFBQQsUaqX4KovrYR+/6Z5si2Ng55LZny1uhcVqnhjaZoNx10fuyJys5+0ociw1CeimgUIRAOjuUtysLC/NhbB4eP/bmz4VCQVs4BwI0UJeO6dS6TXH1cp2kY2R5nEiKiBAEfp1/8IGd7je/VdSAGhyaNUG93sUROSiIUka5c+XSG4PZ3IvR3OwJCHbtGNvRcO+Gp6YyQynrPJW1Lo5CBDGZtgERgASMAEEEuHaD/lo4ODL5hfv7DUBolWrWJMn1SsvWDw6/NWkBgJ1yU0Bgi4BaQz7dk529c5sVVeoNgVmXcvzbqnvyx5o7mIa4nLZFhBwD4dOQhEjnUCx95/t+tPdVf1o7zkbE4gKABQDKgSBoTgA2DCuzaY02lZqhAMikleQyFJN4RJKQjI5+6GC//5VtObeHUWAIqJZyIkprxnE0FenqYx8fOVLae+CQDQBRHMmigOZQBMIIePJIOT/kQkxSbcQApQowmAZiAzYDftGK1EbhZhHZTKGRFgEkDEQUQG0xa5GUvfsPLXOV1VLgYOnGl+n5axlGAikrEQSA2hEAKB5/pQrIPZ53PD9l6uLWqotz0mlXZjCD4eFt+OPMD/PFYjFO0vL6AgggMg0vpJ0EQjQgrARgE8LFUTilUXzC+P7LpT6LcRsoywQYAbQCxke7Q7i4TLFgAEgrhEufRYQkCcB0UmW1U9sbQhMHBIDR0RMO3BYIE/CMiS+Eyn6cZMnzPPi+j54CVgPCJngi0BaNhR4H56pAeOCdT3IzMzMYBtAEL129MOf7B02S/9KXgBVD6BkFn+boay+UVwLe6kGYGBGRZT5OChV6Gb9hCKW1fSL7abNWBmE2gbAZgvISCNUqdkntEKpGws7MY9nGHA2Rm9CmWR36TRCA3fLmplhvCjBBe9j6MEicK3IFIWfSoRkAiGOLQHJ6VSUMBYxXuE/BRKMU9/FZzAiCWWOMWDaDhgcKE/rqZ+vn1jx/+Yyys49EtemApN1hA9LG/1jvPE86IU5NwU3n9b6BgcEtCwtzv1zcuX1SREgUJjSKBTPy3OW7lJU6TZ0eMMFs1zqyO3fqfN6+FITGItndaxQ2mlJhZiCT2RKGIeph/dHxY973hYkJzaV3gpFnLt7LVOY9mPBuSJxqlpS2e8HaInL2FUT9dMXNImcMSHU2DKoHx99/+7trbXmHi8n2PZVbjAnTCIKOi+1a+7UZwt8AnP5oSQGutsOj/ut/tl5M2q9mve6F/3IUCgXdu2p60rXYeRi7IePJqSj4P41/ANmOiHEG2dDCAAAAAElFTkSuQmCC", Scope = Public, Description = 42617365363420504E472069636F6E20283332783332292073686F776E20696E2074686520494445204C6962726172792E
	#tag EndConstant

	#tag Constant, Name = NavigatorIcon, Type = String, Dynamic = False, Default = \"iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAC3ElEQVR42p2TT2xUZRTFz/ne92aY15k3HadNlZBGC8VQTIiJKYkLZeUKl49o4sI/C2JsowUGAgkM0xjQWIqZajCEhWvGnTFRF0bdgJr4J4WoVcuCygy0ZaRT5s+b7/sui1YjkQ3e/Tkn997fAQCgKAr3OVEUeQBAQAhQoui8V90chY3WX1JfJIdz36nR8Au1ivRdwnQ6jdXa7yszMzMdACQAbHl56RnqoGy6rX6KoVMpDiZnO09kPmnGEmhFC1k3UKTzPB9x3D3+3tSxD7llfC4pt3svJ3vymwPU4UTQQh+kXavsyk6NucZU/exZdtf1BCATh99+2tjOeSf2cf3YQwPpC7Pt3t2jDfPu3vxNY5x7sdwd+PQb3fjg3Kkb44W+Q/uOnOg3puuoPGWda5w+eXBy/ODkNUUMqrk/RDIp2s9/gN75xnL+yf31B76fJ3MZUSJCEfcwBEMCGQK4VQHDExPTOQjoBEaHIXBtCdw2CHl2Z6plHexHF5H49QpIUgC8eq8vjBVKPgDoMAQWFoWZgDK80bPWwqYSgLEQReC1A2/+6Hl4RGsfcdyZyqXsyWp1I4maCAC9sAAEScqFX0Rd/HkldA5Wb8ghTBM1AVp2w55AdxJiDaxqVkultwxQVOOFNXT09k3A178Jn3uKbnpv/7I1zr1UdgOffSsEgHPTB+b+u8BxASbXDC4vAOkk3VeXRO0+Vu91TlxtNUQ2oCwBjKJLPlCyADAyMiKlUkmiqKIAwPM80S4mVQKq0XSyfMtoEdggA1GeEgACbLeVSsX+O79S2WPHCiVru6JVb/tWUwQdnQwYJCBBElQExVkFgPPzUGu4C9f55+uFyUcV+aCv3fU1lF9ZfEHpnrKYVpYw7LKHm/Tsymj242rsAoL2b5JBKqe1zpo4fr/8TvHEP2Xa+vyffczm8zQr0nbkUM9P3o7gS7+LxF3n830f7aa5eWb66NV1tP9fnYvFogKAOx0wTJv7m/yDAAAAAElFTkSuQmCC", Scope = Public, Description = 42617365363420504E472069636F6E20283136783136292073686F776E20696E2074686520494445204E6176696761746F722E
	#tag EndConstant


	#tag ViewBehavior
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Height"
			Visible=true
			Group="Position"
			InitialValue="34"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Width"
			Visible=true
			Group="Position"
			InitialValue="100"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockBottom"
			Visible=true
			Group="Position"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockHorizontal"
			Visible=true
			Group="Position"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockLeft"
			Visible=true
			Group="Position"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockRight"
			Visible=true
			Group="Position"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockTop"
			Visible=true
			Group="Position"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="LockVertical"
			Visible=true
			Group="Position"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="PanelIndex"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="_mPanelIndex"
			Visible=false
			Group="Behavior"
			InitialValue="-1"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="ControlID"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Enabled"
			Visible=true
			Group="Behavior"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="_mName"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="AutoLayout"
			Visible=true
			Group="Behavior"
			InitialValue="True"
			Type="Boolean"
			EditorType="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="DropShadow"
			Visible=true
			Group="Behavior"
			InitialValue="False"
			Type="Boolean"
			EditorType="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="LightAccent"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="DarkAccent"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Collapsed"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Theme"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ExpandedWidth"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="CollapsedWidth"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="ResponsiveBreakpoint"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="SelectedItemID"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ItemCount"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="InitialValue"
			Visible=true
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="TabIndex"
			Visible=true
			Group="Visual Controls"
			InitialValue=""
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Visible"
			Visible=true
			Group="Visual Controls"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Indicator"
			Visible=true
			Group="Visual Controls"
			InitialValue="0"
			Type="WebUIControl.Indicators"
			EditorType="Enum"
			#tag EnumValues
				"0 - Default"
				"1 - Primary"
				"2 - Secondary"
				"3 - Success"
				"4 - Danger"
				"5 - Warning"
				"6 - Info"
				"7 - Light"
				"8 - Dark"
				"9 - Link"
			#tag EndEnumValues
		#tag EndViewProperty
		#tag ViewProperty
			Name="Logo"
			Visible=true
			Group="Header"
			InitialValue=""
			Type="Picture"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Title"
			Visible=true
			Group="Header"
			InitialValue="Workspace"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Subtitle"
			Visible=true
			Group="Header"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
