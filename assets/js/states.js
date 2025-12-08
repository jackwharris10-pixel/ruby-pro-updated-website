
function get_state() {
    const url = window.location.href;
    const parts = url.split("/");
    let state = parts[parts.length -1]
    if (state.includes("html")) {
        let state_parts = state.split(".");
        state = state_parts[state_parts.length -2];
    }
    return state;
}

async function load_content(state) {
    let state_file = '/assets/js/' + state + '.json'
    try {
        const response = await fetch(state_file);
        if (!response.ok) {
            throw new Error('Network response was not ok ' + response.statusText);
        }
        return await response.json(); // parse JSON
    } catch (error) {
        console.error("Error reading JSON:", error);
    }
}

function show_why_ruby_pro(content) {
    let lines = content.why_ruby_pro;
    let output = "<ul class='lh-lg mp-0'>";
    lines.map((line) => {
        output += "<li>" + line + "</li>"
    });
    output = output + "</ul>";
    let element = document.getElementById("why-list");
    element.innerHTML = output;
}

function show_problem(content) {
    let lines = content.problem;
    let output = "<ul class='lh-lg mp-0'>";
    lines.map((line) => {
        output += "<li>" + line + "</li>"
    });
    output = output + "</ul>";
    let element = document.getElementById("problem-list");
    element.innerHTML = output;
}

function show_difference(content) {
    let lines = content.difference;
    let output = "<ul class='lh-lg mp-0'>";
    lines.map((line) => {
        output += "<li>" + line + "</li>"
    });
    output = output + "</ul>";
    let element = document.getElementById("difference-list");
    element.innerHTML = output;
}

function show_how(content) {
    let lines = content.how_it_works;
    let output = "<ol class='fs-5 lh-lg'>";
    lines.map((line) => {
        output += "<li>" + line + "</li>"
    });
    output = output + "</ol>";
    let element = document.getElementById("how-it-works-list");
    element.innerHTML = output;
}

function show_state_name(content) {
    let element_ids = [
        "built-for-state-name",
        "why-state-name"
    ]
    element_ids.map((name) => {
        let element = document.getElementById(name);
        element.innerHTML = content.name;
    });
}

async function main() {
    let state = get_state();
    let content = await load_content(state)

    show_why_ruby_pro(content);
    show_problem(content);
    show_difference(content);
    show_how(content);
    show_state_name(content);
}