module EmTask
using Toolips
using ToolipsSession
using ToolipsDefaults
using Dates
import Base: write
import Toolips: write!

mutable struct Task{S <: Any} <: Servable
    name::String
    date::Date
    taskdata::Dict{Symbol, Any}
    T::Symbol
    Task{T}(name::String, date::Date) where {T <: Any} = new{T}(name, date,
    Dict{Symbol, Any}(), T)
end

function write!(c::Toolips.AbstractConnection, t::Task{<:Any})

end

function write(io::IO, t::Task{<:Any})
    tdata = join(["|$k => $v" for (k, v) in t.taskdata])
    write(io, "$(t.date)|$(t.name)|$(t.T)|$tdata\n")
end


mutable struct Tasks <: Toolips.ServerExtension
    type::Symbol
    tasks::Dict{Date, Vector{Task}}
    Tasks() = new(:connection, Dict{Date, Vector{Task}}())
end

"""
home(c::Connection) -> _
--------------------
The home function is served as a route inside of your server by default. To
    change this, view the start method below.
"""
function home(c::Connection)
    emtsheet = ToolipsDefaults.sheet("emtask-sheet")
    write!(c, emtsheet)
    cfg_uri::String = homedir() * "/emtask.cfg"
    if ~(isfile(cfg_uri))
        nameheading = h("nameheading", 1, text = "enter your name")
        style!(nameheading, "color" => "white")
        tdiv = ToolipsDefaults.textdiv("nameinput", text = "")
        style!(tdiv, "background-color" => "#4e08aa", "color" => "white")
        setup_button = button("setupbttn", text = "setup !")
        style!(setup_button, "font-size" => 15pt, "margin-top" => 3px,
        "margin-left" => 5px)
        bod = body("main-body")
        style!(bod, "background-color" => "#2b2242", "padding" => 10percent)
        on(c, setup_button, "click") do cm::ComponentModifier
            name = cm[tdiv]["text"]
            if name != ""
                touch(cfg_uri); open(cfg_uri, "w") do o::IO
                    write(o, name * "\n")
                end
                redirect!(cm, "/")
            end
        end
        push!(bod, nameheading, tdiv, setup_button)
        write!(c, bod)
        return
    end
    uname::String = ""
    for line in readlines(cfg_uri)
        if uname == ""
            uname = string(line)
            continue
        end
        pieces = split(line, "|")
        newd = Date(pieces[1])
        newname = pieces[2]
        tsk = Task{Symbol(pieces[3])}(newname, newd)
    end
    bod = body("main-body")
    style!(bod, "background-color" => "#2b2242", "padding" => 10percent)
    #==
    Main app
    ==#
    write!(c, bod)
end

fourofour = route("404") do c
    write!(c, p("404message", text = "404, not found!"))
end

routes = [route("/", home), fourofour]
extensions = Vector{ServerExtension}([Logger(), Files(), Session(), Tasks()])
"""
start(IP::String, PORT::Integer, ) -> ::ToolipsServer
--------------------
The start function starts the WebServer.
"""
function start(IP::String = "127.0.0.1", PORT::Integer = 8000)
     ws = WebServer(IP, PORT, routes = routes, extensions = extensions)
     ws.start(); ws
end
end # - module
