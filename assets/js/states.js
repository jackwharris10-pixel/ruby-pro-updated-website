console.log("Loaded script");

function show_list() {
    console.log("Got here");
    let lines = [
        "Credit checks before release, automatically",
        "Price posing without double entry",
        "3PL integrations that make end of day easy"
    ];
    let output = "<ul class='list-unstyled lh-lg mp-0>'";
    lines.map((line) => {
        output += "<li>" + line + "</li>"
    });
    output = output + "</ul>";
    console.log(output);
    return output;
}