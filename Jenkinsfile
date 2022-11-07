// =============================================================================
// Jenkinsfile -- Jenkins build pipeline definition
//
// Copyright (C) 2021 Kayisoft, Inc.
//
// Author: Mohammad Matini <mohammad.matini@outlook.com>
// Maintainer: Mohammad Matini <mohammad.matini@outlook.com>
//
// Description: Defines Jenkins build pipeline for Kayicoy.
//
// This file is part of Kayicoy.
//
// Kayicoy is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Kayicoy is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Kayicoy. If not, see <https://www.gnu.org/licenses/>.

def new_image

pipeline {
  environment {
    image_name = "connected/kayicoy"
  }

  agent {
    kubernetes {
      label  "docker-${UUID.randomUUID().toString()}"
      defaultContainer 'docker'
      inheritFrom 'docker'
    }
  }

  stages {
    stage('fetch') { steps { checkout scm } }

    stage('build') {
      steps {
        script {
          new_image = docker.build("${env.image_name}:${GIT_COMMIT.take(7)}")
        }
      }
    }

    stage('push') {
      steps {
        script {
          docker.withRegistry("${REGISTRY_URL}", "${REGISTRY_CREDENTIALS}") {
            new_image.push()
            if (GIT_BRANCH == 'master') { new_image.push('latest') }
            else if (GIT_BRANCH) { new_image.push(GIT_BRANCH.replace('/', '_')) }
            else if (GIT_TAG) { new_image.push(GIT_TAG) }
          }
        }
      }
    }
  }
}
