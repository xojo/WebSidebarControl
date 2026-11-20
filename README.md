# WebSidebar

A reusable navigation sidebar for Xojo Web 2 apps.

- **Bootstrap only.** The control ships no stylesheet. It is built from the Bootstrap 5 classes and components that Xojo already loads: nav pills, utility classes, badges, offcanvas, dropdowns, tooltips and the `fade`/`show` transition.
- **Responsive.** An expanded sidebar, a collapsed icon rail, and an overlay drawer on narrow viewports.
- **Automatic layout.** The sidebar repositions the rest of the page for you.

## Quick start

1. Import `WebSidebar.xojo_code` into a Xojo Web project.
2. Drag the class onto a page or container and name the instance `Navigation`.
3. Set its position and initial size in the layout. A starting desktop width of 256 pixels works well.
4. In the Inspector's **Header** group, set `Logo`, `Title` and `Subtitle`. `Logo` accepts a project Picture; leaving it empty uses the first letter of the title. The layout editor previews the configured header.
5. Type your menu into the **InitialValue** property (see below), or add items in code, and handle `ItemPressed`.

```
#Workspace
<bi-house> Home
<bi-folder> Projects
<bi-people> Team
  <bi-person> Members
```

```xojo
Sub ItemPressed(itemID As String)
  // The ID of an InitialValue entry is its caption, e.g. "Members".
  ContentTitle.Text = itemID
End Sub
```

In `Navigation.ItemPressed(itemID As String)`, switch your page, panel or container. The control does not implement application routing or permissions.

## Defining items in the Inspector

The **InitialValue** property builds the whole menu from text, one entry per line. The layout editor previews it, and the same entries appear in the running app.

| Line | Result |
| --- | --- |
| `#Workspace` | A section heading. |
| `---` | A separator. |
| `<bi-house> Overview` | An item with the Bootstrap icon `bi-house`. The icon goes in angle brackets before the caption and is optional: `Overview` alone is an item without one. |
| `  <bi-person> Members` | A line indented by a space or tab is a child of the item above it. One level is supported. |

- **The ID is the caption.** The entry `Overview` has the item ID `Overview`, so `ItemPressed("Overview")`, `SelectedItemID = "Overview"` and the other methods use the text you typed. Sections use `#` plus the caption (`#Workspace`), and separators are numbered (`---1`, `---2`).
- **Captions must be unique** and at most 80 characters. A repeated or too-long caption raises `InvalidArgumentException` with a message that names it.
- **Icons are written in angle brackets** before the caption, for example `<bi-house> Overview`, in lowercase with the `bi-` prefix. Any Bootstrap Icons name works at runtime. The built-in icon names also work, as in `<home> Overview`. The layout editor does not have the icon font, so it draws a generic circle where an icon will appear.
- **Badges, footer placement, links, pictures and disabled state** are set in code, using the item's caption as its ID. For example `Navigation.SetBadge("Inbox", "5")` or `Navigation.AddItem("Settings", "Settings", "settings", "", "", True)`.
- Setting `InitialValue` at runtime rebuilds the menu and removes any items added in code.

`SidebarControl` is the demo project (debug port 8080). Its **Second instance** button switches between two independently configured controls.

## How it looks and behaves

| State | What you get |
| --- | --- |
| Expanded | Header with logo, title and subtitle; main navigation that scrolls on its own; footer items pinned to the bottom; a **Collapse** button in a bar at the very bottom. |
| Collapsed rail | Icons only. Captions are hidden and shown as tooltips. Badges become small pills on the icon's corner. Section headings become thin dividers. A group opens a flyout menu beside the rail, and its icon is marked active when one of its children is selected. |
| Mobile | A menu button in a top bar. It opens a drawer (Bootstrap offcanvas) 288 pixels wide, bounded by the viewport. |

When the rail changes state, labels fade in. Reduced-motion preferences are respected by Bootstrap's transition rules.

## Layout

`AutoLayout` defaults to True. Arrange the page in the IDE with the sidebar at the top left, expanded, and the content beside it. No page `Resized` handler, sidebar `LayoutChanged` handler or page layout method is required.

The sidebar captures the original bounds and locks of the visual controls in its immediate parent and manages those siblings only. A container moves and resizes as a unit while its children keep their own layout. Nonvisual controls and other sidebar instances are excluded. Hidden content is included so it has the correct bounds when shown later.

- **Expanded desktop:** the designed spacing beside the sidebar is preserved.
- **Collapsed desktop:** the difference between the original reservation and the collapsed width is released.
- **Mobile:** the left reservation is released and 60 pixels are added above the content for the menu button. The drawer overlays the page.
- **Resizing:** positions are calculated from the saved bounds and locks, including opposite-edge stretching, right/bottom anchoring and proportional centering. Offsets never accumulate across transitions.

Use left and right locks on content that should stretch with the available width. Fixed-size controls keep their size and can be clipped on small screens. Automatic layout does not rearrange rows, wrap controls or infer a mobile design.

Use one visible automatic sidebar per parent. Alternating instances share the first captured baseline and keep independent navigation and collapsed states. Responsive mode follows the browser viewport, including when the sidebar is inside a container.

The baseline is captured during Opening, before the sidebar first lays out content, and covers controls present at that point. Pages that add controls later, use Flex layout, or position controls with their own code should set `AutoLayout = False` before the sidebar is first shown and manage layout themselves.

### Custom layouts

To keep an existing custom layout, set `AutoLayout = False` in the Inspector or in the page's Opening event. The `LayoutChanged(reservedWidth As Integer, overlay As Boolean)` event stays available. With automatic layout off, the desktop `reservedWidth` is the expanded or collapsed width, and mobile reports zero with `overlay = True`. Give the mobile control a full-width, 60-pixel-high area.

## Properties

| Property | Default | Meaning |
| --- | --- | --- |
| `AutoLayout As Boolean` | True | Positions the sidebar and lays out its original visual siblings. Set before first display. |
| `DropShadow As Boolean` | False | Draws a subtle Bootstrap shadow (`shadow`) along the sidebar edge to separate it from the page. Not shown in the mobile top bar. Available in the Inspector. |
| `Logo As Picture` | Nil | Header picture, scaled to fit a 32 x 32 area without cropping. Available in the Inspector and at runtime; assign Nil to restore the monogram. |
| `Title As String` | `Workspace` | Header title, and the source of the fallback monogram. Available in the Inspector and at runtime. |
| `Subtitle As String` | empty | Secondary header text. Available in the Inspector and at runtime. |
| `SelectedItemID As String` | empty | Selected leaf item. Empty clears the selection. |
| `ItemCount As Integer` | 0 | Read-only count, including sections and separators. |
| `Collapsed As Boolean` | False | Desktop collapsed-rail state. Kept while in mobile mode. |
| `ExpandedWidth As Integer` | 256 | Desktop expanded width, minimum 160. |
| `CollapsedWidth As Integer` | 72 | Collapsed width, clamped between 64 and `ExpandedWidth`. |
| `ResponsiveBreakpoint As Integer` | 768 | Mobile mode below this viewport width, minimum 320. |
| `Theme As String` | `auto` | `light`, `dark` or `auto`. Automatic inherits the host app's Bootstrap color mode. |
| `LightAccent As String` | empty | Optional light-mode accent as `#RRGGBB`. Empty uses the host's selected-pill color. |
| `DarkAccent As String` | empty | Optional dark-mode accent as `#RRGGBB`. Empty uses the host's selected-pill color. |

## Methods

```xojo
AddItem(itemID As String, caption As String, icon As String = "", _
  parentID As String = "", badge As String = "", footer As Boolean = False)
AddSection(sectionID As String, caption As String)
AddSeparator(separatorID As String)
RemoveItem(itemID As String)
Clear()
ContainsItem(itemID As String) As Boolean
SelectItem(itemID As String)
SetBadge(itemID As String, value As String)
SetCaption(itemID As String, value As String)
SetIcon(itemID As String, value As String)
SetItemEnabled(itemID As String, value As Boolean)
SetItemVisible(itemID As String, value As Boolean)
ToggleCollapsed()
OpenDrawer()
CloseDrawer()
```

- IDs are case-sensitive, unique per instance, and 1 to 80 characters of any text without control characters, so a caption can serve as its own ID. Captions are rendered as text.
- Add the parent before its children. One submenu level is supported. A parent with children acts as a disclosure button, not a selectable destination. Children follow their parent's footer placement.
- Removing a parent also removes its children. Removing, hiding or disabling the selected item or its parent clears the selection. Adding children to a selected leaf clears its selection, because it becomes a group.
- Selecting an unknown, hidden, disabled, section, separator or group item raises `InvalidArgumentException`. So do duplicate or invalid IDs, an invalid parent, a deeper submenu, setters targeting an unknown ID, invalid themes and invalid accent colors. `RemoveItem` with an unknown ID does nothing.
- Programmatic changes do not raise click or selection events. Update your application's content yourself when you select from code.
- `OpenDrawer` is meant for mobile mode. The drawer width is fixed at 288 pixels, so the desktop width properties do not change it.

### Icons

Built-in names: `home`, `folder`, `inbox`, `users`, `chart`, `grid`, `settings` and `help`. An unknown name uses a small line fallback. An item with an empty icon shows its caption when expanded and its first character in the rail. `SetIcon` and `AddItem` also accept a Bootstrap Icons class such as `bi-inbox`; Xojo supplies the icon font. The built-in icons are inline SVG, so no icon assets are loaded.

### Customizing items

| Method | Behavior |
| --- | --- |
| `SetItemCSSClasses(itemID As String, classes As String)` | Sets space-separated classes on the item button, link, section label or separator. Pass an empty string to clear them. |
| `SetGroupExpanded(itemID As String, expanded As Boolean)` | Expands or closes an existing parent after its children have been added. Keeps the current selection. The rail remembers the state for its next expanded view. |
| `SetIcon(itemID As String, value As String)` | Accepts a built-in name or a Bootstrap Icons class. |
| `SetItemPicture(itemID As String, picture As Picture)` | Shows a Picture in place of the named icon. Nil restores the named icon. Calling `SetIcon` replaces the picture. |
| `SetItemURL(itemID As String, url As String)` | Makes a leaf item a native link. Accepts HTTP(S) or relative references, including paths, queries and fragments. Encode spaces as `%20`. Pass an empty string to restore normal activation. |

```xojo
Navigation.SetItemCSSClasses("inbox", "inbox-link")
Navigation.SetIcon("inbox", "bi-inbox")
Navigation.SetGroupExpanded("team", True)
Navigation.SetItemURL("help", "https://documentation.xojo.com/")
```

Style one item with a selector such as `.xojo-sidebar .inbox-link`. Classes survive selection changes, re-renders and drawer transitions.

Enabled URL items use the browser's native link actions, including Enter, opening in another tab and copying the address. Activating a link leaves the selection alone and raises neither `ItemPressed` nor `SelectionChanged`. Use `SelectedItemID` to mark the current destination on its own page. A disabled link loses its destination until it is enabled again. Clear a parent's URL before adding children. Ordinary leaf buttons keep their normal event behavior.

## Events

| Event | When |
| --- | --- |
| `ItemPressed(itemID As String)` | Every valid non-URL leaf activation, including clicking the selected item again. |
| `SelectionChanged(itemID As String)` | A user activation changes the selected item. |
| `CollapsedChanged(collapsed As Boolean)` | The user collapses or expands the rail. |
| `DrawerChanged(open As Boolean)` | The user opens or closes the mobile drawer. Selecting an item, pressing Escape and clicking the backdrop all close it. |
| `LayoutChanged(reservedWidth As Integer, overlay As Boolean)` | The initial browser configuration, a breakpoint crossing, or a change that affects the desktop reserved width. |

The server validates event parameter types and rejects unknown, disabled, hidden or non-leaf destinations. Your application must still enforce permissions when it displays or changes protected content.

## Styling

The control adopts the host theme's typography, spacing, corners and selection colors. Main, nested and footer navigation are Bootstrap nav pills. The selected destination gets `active` and `aria-current="page"`. Counts are `badge text-bg-secondary`. Layout is done with Bootstrap utility classes, so there is no stylesheet to load or override. The layout editor previews the content, and the browser shows the real theme.

`Theme` set to `auto` inherits the host color mode. Explicit light and dark modes apply to that instance only. A nonempty accent sets the selected pill's background in its mode and picks a black or white foreground for contrast. Clearing it restores the host's nav-pill colors.

### Custom CSS

The control marks its parts with unstyled hook classes, so any rule you write applies on top of Bootstrap by normal specificity:

| Hook | Element |
| --- | --- |
| `.xojo-sidebar` | The control's root. `.xs-compact` and `.xs-mobile` are added in those states. |
| `.xs-header`, `.xs-brand`, `.xs-logo` | The header and its brand area. |
| `.xs-nav`, `.xs-footer`, `.xs-list` | Main and footer navigation. |
| `.xs-item`, `.xs-badge`, `.xs-children` | Items, badges and groups. |
| `.xs-toolbar`, `.xs-toggle` | The bottom bar and its collapse button. |
| `.xs-drawer` | The mobile drawer. |

To style a single instance, give it a CSS class such as `workspace-navigation`, as the demo's Navigation control does. This rule recolors the selected pill, including nested items and the drawer. Leave the accent properties empty when you use it.

```css
.xojo-sidebar.workspace-navigation .nav-pills {
  --bs-nav-pills-link-active-bg: #34495e;
  --bs-nav-pills-link-active-color: white;
}
```

A few values are set inline because Bootstrap has no class for them: the drawer width variable, the logo and item-picture sizes, and the accent variables when an accent is set.

## Accessibility

- The control uses navigation landmarks, buttons, current-page and disclosure states, visible focus and accessible labels.
- Tab, Shift+Tab, Enter and Space work as usual. Up/Down and Home/End move through each navigation region. Rail flyouts use Bootstrap's dropdown keyboard handling, including Escape to close.
- The mobile drawer is a Bootstrap offcanvas with a focus trap. Closing it returns focus to the control that opened it.
- Rail icons have tooltips on hover, and every item has an accessible label.
- Main navigation scrolls independently of the header and footer.

## Requirements

A Xojo Web 2 project.

## References

- [Xojo WebSDKUIControl](https://documentation.xojo.com/api/user_interface/web/websdkuicontrol.html)
- [Xojo text-format reference](https://github.com/xojo/XojoProjectFormatReference)
