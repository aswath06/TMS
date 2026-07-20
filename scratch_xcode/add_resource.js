const xcode = require('xcode');
const fs = require('fs');

const projectPath = '../ios/Runner.xcodeproj/project.pbxproj';
const myProj = xcode.project(projectPath);

myProj.parse(function (err) {
    if (err) {
        console.error("Error parsing project:", err);
        process.exit(1);
    }
    
    // Check if already added
    const pbxFile = myProj.addResourceFile('alerttone.mp3');
    if (!pbxFile) {
        console.log("File is already in the project, or failed to add.");
    } else {
        console.log("Added alerttone.mp3 to the project!");
        fs.writeFileSync(projectPath, myProj.writeSync());
        console.log("Successfully wrote project.pbxproj");
    }
});
