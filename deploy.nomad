variable "dcs" {
  type    = list(string)
  default = ["dc1", "dev"]
}

variable "fqdn" {
  type    = string
  default = "rabbit-ui.fejk.net"
}

job "rabbitmq" {
  datacenters = var.dcs
  type        = "service"
  namespace   = "default"

  group "cluster" {
    count = 1

    update {
      max_parallel = 1
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "5s"
      healthy_deadline = "30s"
    }


    network {
      port "amqp" {
        to = 5672
      }
      port "ui" {
        to = 15672
      }
      port "discovery" {
        static = 4369
      }
      port "clustering" {
        static = 25672
      }


    }


    service {
      name = "rabbitmq"
      port = "ui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.rabbitmq-ui.rule=Host(`${var.fqdn}`)",
        "management",
        "http"
      ]
    }

    ephemeral_disk {
      size    = 300
      sticky  = true
      migrate = true
    }


    task "rabbit" {
      driver = "docker"

      config {
        image    = "pondidum/rabbitmq:consul"
        hostname = attr.unique.hostname

        ports = [
          "amqp",
          "ui",
          "discovery",
          "clustering"
        ]

      }

      env {
        RABBITMQ_ERLANG_COOKIE = "rabbitmq"
        RABBITMQ_DEFAULT_USER  = "administrator"
        RABBITMQ_DEFAULT_PASS  = "123SecurePassword..."

        CONSUL_HOST     = attr.unique.network.ip-address
        CONSUL_SVC_PORT = NOMAD_HOST_PORT_amqp
        CONSUL_SVC_TAGS = "amqp"
      }

      resources {
        cpu = 100
        memory = 64
        memory_max = 128
      }

    }


  } // END group cluster

}
