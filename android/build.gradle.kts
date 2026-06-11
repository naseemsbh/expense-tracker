// 1. ADD THIS BLOCK AT THE TOP
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // This is the Google Services plugin
        classpath("com.google.gms:google-services:4.4.0")
    }
}

// 2. EXISTING CODE STARTS HERE
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}