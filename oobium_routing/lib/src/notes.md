# Routes vs State

there is only 1 Routes object in the system. it is the top level object

there can be many State objects - 1 for the top level, and then 1 for each child

**Routing** may make more sense than **Routes** though... with 'Routes' being contained within 'Routing'...

# Top Level Routes

Home Route is usually a top level route

LoginPage is usually not a top level route (used as a guard), but is auto-routed (by a guard)
 the back button is all kinds of messed up in this case (can't back out and close the app)

# AppRouterState

extending is awkward... we really just want to have the router listen to other things...

# Guards

guards may want to check state in:
- the AppRouterState (or custom subclass)
- something on the BuildContext (providers / riverpod / etc)
- the route being guarded (check for valid params)

the current method of appended guarded pages is problematic (duplicate pages in the route stack, for instance)

really, we should be forwarding (like redirecting, but adding to the backstack... maybe?)

should there be a way to pop the user back to the initial route?
for example, once a location is selected, automatically return the user to the route that depended on the location...