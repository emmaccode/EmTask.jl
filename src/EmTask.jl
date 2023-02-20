module EmTask
using Toolips
using ToolipsSession
using ToolipsDefaults
using TOML
using Dates
using Alert
import Base: write

mutable struct Task <: Servable
    name::String
    date::Date
    taskdata::Dict{String, Any}
    Task(name::String, date::Date) = new(name, date,
    Dict{String, String}("status" => "undone"))
    Task(name::String, date::Date, dct::Dict{String, Any}) = new(name, date,
    dct)
end

function build_task(c::Connection, t::Task)
    mainsection = section("$(t.name)-box")
    nameheader = h("$(t.name)-name", 3, text = t.name)
    status = button("$(t.name)-status", text = "not done")
    style!(status, "display" => "inline-block", "background-color" => "red",
    "width" => 100percent)
    on(c, status, "click") do cm::ComponentModifier
        style!(cm, status, "background-color" => "green")
        set_text!(cm, status, "done!")
        t.taskdata["status"] = true
        save(c, t)
    end
    if t.taskdata["status"] == true
        style!(status, "background-color" => "green")
        status[:text] = "done!"
    end
    push!(mainsection, nameheader, status)
    mainsection
end

function save(c::Connection, t::Task)
    cfg_uri = c[:Tasks].cfg_uri
    toml_dct = TOML.parse(read(cfg_uri, String))
    toml_dct["tasks"][t.name] = copy(t.taskdata)
    push!(toml_dct["tasks"][t.name], "date" => string(t.date))
    open(cfg_uri, "w") do o::IO
           TOML.print(o, toml_dct)
    end
end


mutable struct Tasks <: Toolips.ServerExtension
    type::Symbol
    tasks::Dict{Date, Vector{Task}}
    cfg_uri::String
    Tasks() = new(:connection, Dict{Date, Vector{Task}}(),
    homedir() * "/emtask.cfg")
end

"""
home(c::Connection) -> _
--------------------
The home function is served as a route inside of your server by default. To
    change this, view the start method below.
"""
function home(c::Connection)
    cfg_uri::String = c[:Tasks].cfg_uri
    emtsheet = ToolipsDefaults.sheet("emtask-sheet")
    write!(c, emtsheet)
    bod = body("main-body")
    if ~(isfile(cfg_uri))
        push!(bod, img("taskcover", src = "/emtask.png"))
        nameheading = h("nameheading", 1, text = "enter your name")
        style!(nameheading, "color" => "white")
        tdiv = ToolipsDefaults.textdiv("nameinput", text = "")
        style!(tdiv, "background-color" => "#4e08aa", "color" => "white")
        setup_button = button("setupbttn", text = "setup !")
        style!(setup_button, "font-size" => 15pt, "margin-top" => 3px,
        "margin-left" => 5px)
        style!(bod, "background-color" => "#2b2242", "padding" => 10percent)
        on(c, setup_button, "click") do cm::ComponentModifier
            name = cm[tdiv]["text"]
            if name != ""
                touch(cfg_uri); open(cfg_uri, "w") do o::IO
                    write(o, """name = "$name"\n[repeating]\n[tasks]\n""")
                end
                redirect!(cm, "/")
            else
                alert!(cm, "please enter a name")
            end
        end
        push!(bod, nameheading, tdiv, setup_button)
        write!(c, bod)
        return
    end
    uname::String = ""
    emtask_data::Dict{String, Any} = TOML.parse(read(cfg_uri, String))
    #==
    Main app
    ==#
    push!(bod, img("taskcover", src = "/emtask.png"))
    style!(bod, "background-color" => "#2b2242", "padding" => 10percent)
    datepanel = iframe("datepanel")
    this_day = today()
    dsections = [Date(year(this_day), month(this_day), day(this_day) + e) for e in 0:6]
    tasks_dct = Dict{String, Vector{Task}}([dayname(d) => Vector{Task}() for d in dsections])
    raw_tasks = TOML.parse(read(cfg_uri, String))
    ui_sections = Vector{Servable}([build_section(c, d) for d in dsections])
    [begin

    end for task in raw_tasks["repeating"]]
    [begin
        task_date = Dates.Date(task[2]["date"])
        if task_date in dsections
            dayn::String = dayname(task_date)
            new_task = Task(task[1], task_date, task[2])
            push!(tasks_dct[dayn], new_task)
            push!(ui_sections["panel$(dayn)"][:children]["$(dayn)-box"][:children], build_task(c, new_task))
        end
    end for task in raw_tasks["tasks"]]
    newbox = section("newpanel")
    style!(newbox, "background-color" => "white")
    push!(newbox, h("add1label", 4, text = "add new task"))
    opts = Vector{Servable}([begin
    comp = Component("day", "option")
    comp[:text] = dayname(dayn)
    comp
    end for dayn in dsections])
    dd = ToolipsDefaults.dropdown("mydrop", opts)
    newnamebox = ToolipsDefaults.textdiv("newname", text = "enter new name")
    on(c, newnamebox, "focus") do cm::ComponentModifier
        set_text!(cm, newnamebox, "")
    end
    style!(newnamebox, "border-width" => 2px, "border-style" => "dashed",
    "margin-top" => 5px, "margin-bottom" => 5px)
    addtaskbutton = button("addtaskb", text = "add")
    on(c, addtaskbutton, "click") do cm::ComponentModifier
        sel_day = cm[dd]["value"]
        name = cm[newnamebox]["text"]
        dn = findall(d::Date -> dayname(d) == sel_day, dsections)
        d = dsections[dn[1]]
        save(c, Task(name, d))
        alert!(cm, "task registered")
    end
    push!(newbox, dd, newnamebox, addtaskbutton)
    push!(ui_sections, newbox)
    bod[:children] = ui_sections
    write!(c, bod)
end

function build_section(c::Connection, d::Date)
    dayn = dayname(d)
    sec = section("panel$(dayn)")
    style!(sec, "width" => 16percent, "background-color" => "white")
    style!(sec, "display" => "inline-block")
    push!(sec, h("$(dayn)dheader", 2, text = dayn), h("$(dayn)daheader", 3,
    text = string(d)))
    push!(sec, div("$(dayn)-box"))
    sec::Component{:section}
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
