allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // llama_flutter_android injects its own buildscript classpath with KGP 2.1.0,
    // which conflicts with the app's KGP 2.2.20 and corrupts
    // :app:compileReleaseKotlin (unresolved framework references, "overrides
    // nothing"). Force a single KGP version on every project's buildscript
    // classpath. AGP is intentionally NOT aligned, because the plugin's legacy
    // android{} DSL hard-fails under AGP 9.0.1.
    buildscript {
        configurations.classpath {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin" &&
                    requested.name == "kotlin-gradle-plugin") {
                    useVersion("2.2.20")
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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
