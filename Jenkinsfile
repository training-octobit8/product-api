pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo 'Building..'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing..'
            }
        }

        stage('Terraform init') {
            steps {
                sh 'cd terraform'
                sh 'terraform init'
            }
        }
        stage('Terraform apply') {
            steps {
                sh 'cd terraform'
                sh 'terraform apply --auto-approve'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying....'
            }
        }
    }
}
