pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    } // repositories
} // pluginManagement

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    } // repositories
} // dependencyResolutionManagement

rootProject.name = "XPaddle"
include(":XPaddle")
