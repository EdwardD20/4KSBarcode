pluginManagement {

    repositories {

        google()
        mavenCentral()
        gradlePluginPortal()

    } // repositories

} // pluginManagement

dependencyResolutionManagement {

    repositoriesMode.set(
        RepositoriesMode.FAIL_ON_PROJECT_REPOS
    )

    repositories {

        google()
        mavenCentral()

    } // repositories

} // dependencyResolutionManagement

rootProject.name = "4KSBarcode"

include(":app")
include(":xpaddle")
project(":xpaddle").projectDir = file("Games/XPaddle/XPaddle")
include(":cheaterssolitaire")
project(":cheaterssolitaire").projectDir = file("Games/CheatersSolitaire/app")
