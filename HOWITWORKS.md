# How Makara Works

Simply, makara provides itself to ActiveRecord as a database adapter but **does not** inherit from the AbstractAdapter interface. This is by design. Think of Makara as a proxy to your master database that detects a read / write `execute()` call and passes control back to the proxy. The proxy then decides whether the underlying adapter should continue on with the execution or if it should be passed to a different one.

## Underlying Adapter Decoration

Step one in getting makara to gain control is hijacking all `execute()` calls. This is simple in some cases and more complex in others. 

### Simple Case

Makara receives an `execute()` call directly via `ActiveRecord::Base.connection.execute('some sql')`. This means control is passed directly to the makara adapter and the routing of control is handled immediately.