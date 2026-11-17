pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '5'))
    }

    environment {
        FLUTTER_HOME = '/opt/flutter'
        ANDROID_HOME = '/opt/android-sdk'
        ANDROID_SDK_ROOT = '/opt/android-sdk'
        GRADLE_USER_HOME = '/var/lib/jenkins/.gradle'
        PATH = "/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:${env.PATH}"
    }

    stages {
        stage('Check Environment') {
            steps {
                sh '''
                    set -e
                    flutter --version
                    java -version
                    df -h /
                    free -h
                '''
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    set -e
                    flutter pub get
                '''
            }
        }

        stage('Check Gradle Configuration') {
            steps {
                sh '''
                    set -e
                    cat android/gradle.properties
                    test -f android/gradlew
                    chmod +x android/gradlew
                '''
            }
        }
    }

    post {
        success {
            echo 'GlowScan environment verification passed.'
        }
        failure {
            echo 'Pipeline failed. Check console output.'
        }
    }
}
